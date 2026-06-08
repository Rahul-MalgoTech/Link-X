import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LinkxApiClient {
  LinkxApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'LINKX_API_BASE_URL',
    defaultValue: 'https://linkx-backend-kzjm.onrender.com/api',
  );

  static const tokenKey = 'linkx_auth_token';
  static const _requestTimeout = Duration(seconds: 8);
  final http.Client _httpClient;

  static Future<bool> hasAuthToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(tokenKey);
    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> clearAuthToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(tokenKey);
  }

  Future<void> requestOtp({
    required String phoneNumber,
    String countryCode = '+91',
  }) async {
    await _post('/auth/request-otp', {
      'countryCode': countryCode,
      'phoneNumber': phoneNumber,
    }, authenticated: false);
  }

  Future<LinkxOtpVerificationResult> verifyOtp({
    required String phoneNumber,
    required String otp,
    String countryCode = '+91',
  }) async {
    final data = await _post('/auth/verify-otp', {
      'countryCode': countryCode,
      'phoneNumber': phoneNumber,
      'otp': otp,
    }, authenticated: false);

    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const LinkxApiException('Token missing from verify OTP response');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(tokenKey, token);

    return LinkxOtpVerificationResult.fromJson(data);
  }

  Future<void> updateOnboarding(Map<String, dynamic> payload) async {
    await _patch('/onboarding/me', payload);
  }

  Future<void> completeOnboarding() async {
    await _post('/onboarding/complete', {});
  }

  Future<void> uploadPhotos(List<XFile> photos) async {
    if (photos.isEmpty) return;
    await _uploadPhotos(photos);
  }

  Future<LinkxExplorePage> fetchExploreUsers({
    int page = 1,
    int limit = 20,
    String? identity,
    int minAge = 18,
    int maxAge = 80,
    int maxDistance = 5000,
    String search = '',
    String lookingFor = '',
    List<String> interests = const [],
    bool excludeReacted = false,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'minAge': '$minAge',
      'maxAge': '$maxAge',
      'maxDistance': '$maxDistance',
      'excludeReacted': '$excludeReacted',
      if (identity != null && identity.isNotEmpty) 'identity': identity,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (lookingFor.trim().isNotEmpty) 'lookingFor': lookingFor.trim(),
      if (interests.isNotEmpty) 'interests': interests.join(','),
    };
    final data = await _get('/users/explore', queryParameters: query);
    final users = data['users'];
    final pagination = data['pagination'];
    return LinkxExplorePage(
      users: users is List
          ? users
                .whereType<Map>()
                .map(
                  (user) => LinkxExploreUser.fromJson(
                    Map<String, dynamic>.from(user),
                  ),
                )
                .toList()
          : const [],
      page: pagination is Map
          ? (pagination['page'] as num?)?.toInt() ?? page
          : page,
      limit: pagination is Map
          ? (pagination['limit'] as num?)?.toInt() ?? limit
          : limit,
      total: pagination is Map
          ? (pagination['total'] as num?)?.toInt() ?? 0
          : 0,
      hasMore: pagination is Map && pagination['hasMore'] == true,
    );
  }

  Future<LinkxMatchActionResult> likeUser(String userId) async {
    final data = await _post('/matching/like/$userId', {});
    return LinkxMatchActionResult.fromJson(data);
  }

  Future<LinkxMatchActionResult> passUser(String userId) async {
    final data = await _post('/matching/pass/$userId', {});
    return LinkxMatchActionResult.fromJson(data);
  }

  Future<LinkxMatchStatus> fetchMatchStatus(String userId) async {
    final data = await _get('/matching/status/$userId');
    return LinkxMatchStatus.fromJson(data);
  }

  Future<bool> authorizeCall(String userId) async {
    final data = await _post('/matching/call-authorize/$userId', {});
    return data['allowed'] == true;
  }

  Future<void> unmatchUser(String userId) async {
    await _delete('/matching/matches/$userId');
  }

  Future<void> blockUser(String userId) async {
    await _post('/matching/block/$userId', {});
  }

  Future<void> unblockUser(String userId) async {
    await _delete('/matching/block/$userId');
  }

  Future<void> reportUser({
    required String userId,
    required String reason,
    String details = '',
  }) async {
    await _post('/matching/report/$userId', {
      'reason': reason,
      'details': details,
    });
  }

  Future<LinkxCurrentUser> fetchCurrentUser() async {
    final data = await _get('/users/me');
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const LinkxApiException('Current user is missing');
    }
    return LinkxCurrentUser.fromJson(user);
  }

  Future<LinkxCurrentUser> updateProfile(Map<String, dynamic> profile) async {
    final data = await _patch('/users/me', profile);
    final user = data['user'];
    if (user is! Map) {
      throw const LinkxApiException('Updated user is missing');
    }
    return LinkxCurrentUser.fromJson(Map<String, dynamic>.from(user));
  }

  Future<void> updateAccountSettings({
    Map<String, bool>? privacySettings,
    Map<String, bool>? notificationSettings,
  }) async {
    await _patch('/users/me/settings', {
      if (privacySettings != null) 'privacySettings': privacySettings,
      if (notificationSettings != null)
        'notificationSettings': notificationSettings,
    });
  }

  Future<void> submitSupportRequest({
    required String subject,
    required String message,
  }) async {
    await _post('/users/me/support', {'subject': subject, 'message': message});
  }

  Future<void> deleteAccount() async {
    await _delete('/users/me');
    await clearAuthToken();
  }

  Future<LinkxRoomPage> fetchRooms({
    String? privacy,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _get(
      '/rooms',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (privacy != null) 'privacy': privacy,
      },
    );
    final rooms = data['rooms'];
    final pagination = data['pagination'];
    return LinkxRoomPage(
      rooms: rooms is List
          ? rooms
                .whereType<Map>()
                .map(
                  (room) => LinkxRoom.fromJson(Map<String, dynamic>.from(room)),
                )
                .toList()
          : const [],
      page: pagination is Map
          ? (pagination['page'] as num?)?.toInt() ?? page
          : page,
      hasMore: pagination is Map && pagination['hasMore'] == true,
    );
  }

  Future<LinkxRoom> fetchRoom(String roomId) async {
    final data = await _get('/rooms/$roomId');
    return _roomFromResponse(data);
  }

  Future<LinkxRoom> createRoom({
    required String title,
    required String topic,
    required String privacy,
    required int maxParticipants,
  }) async {
    final data = await _post('/rooms', {
      'title': title,
      'topic': topic,
      'privacy': privacy,
      'maxParticipants': maxParticipants,
    });
    return _roomFromResponse(data);
  }

  Future<LinkxRoom> joinRoom(String roomId, {String? inviteCode}) async {
    final data = await _post('/rooms/$roomId/join', {
      if (inviteCode != null) 'inviteCode': inviteCode,
    });
    return _roomFromResponse(data);
  }

  Future<LinkxRoom> joinPrivateRoom(String inviteCode) async {
    final data = await _post('/rooms/join-by-code', {
      'inviteCode': inviteCode.trim().toUpperCase(),
    });
    return _roomFromResponse(data);
  }

  Future<void> leaveRoom(String roomId) async {
    await _post('/rooms/$roomId/leave', {});
  }

  Future<void> endRoom(String roomId) async {
    await _post('/rooms/$roomId/end', {});
  }

  Future<void> removeRoomMember(String roomId, String userId) async {
    await _delete('/rooms/$roomId/members/$userId');
  }

  Future<LinkxNotificationPage> fetchNotifications({int limit = 50}) async {
    final data = await _get(
      '/notifications',
      queryParameters: {'limit': '$limit'},
    );
    final notifications = data['notifications'];
    return LinkxNotificationPage(
      notifications: notifications is List
          ? notifications
                .whereType<Map>()
                .map(
                  (item) => LinkxAppNotification.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> markNotificationsRead() async {
    await _patch('/notifications/read', {});
  }

  Future<LinkxEventPage> fetchEvents({int page = 1, int limit = 20}) async {
    final data = await _get(
      '/events',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final events = data['events'];
    final pagination = data['pagination'];
    return LinkxEventPage(
      events: events is List
          ? events
                .whereType<Map>()
                .map(
                  (event) =>
                      LinkxEvent.fromJson(Map<String, dynamic>.from(event)),
                )
                .toList()
          : const [],
      page: pagination is Map
          ? (pagination['page'] as num?)?.toInt() ?? page
          : page,
      hasMore: pagination is Map && pagination['hasMore'] == true,
    );
  }

  Future<LinkxEvent> rsvpEvent(String eventId) async {
    final data = await _post('/events/$eventId/rsvp', {});
    return _eventFromResponse(data);
  }

  Future<LinkxEvent> cancelEventRsvp(String eventId) async {
    final data = await _delete('/events/$eventId/rsvp');
    return _eventFromResponse(data);
  }

  LinkxEvent _eventFromResponse(Map<String, dynamic> data) {
    final event = data['event'];
    if (event is! Map) throw const LinkxApiException('Event is missing');
    return LinkxEvent.fromJson(Map<String, dynamic>.from(event));
  }

  Future<List<LinkxBillingPlan>> fetchBillingPlans() async {
    final data = await _get('/billing/plans');
    final plans = data['plans'];
    return plans is List
        ? plans
              .whereType<Map>()
              .map(
                (plan) =>
                    LinkxBillingPlan.fromJson(Map<String, dynamic>.from(plan)),
              )
              .toList()
        : const [];
  }

  Future<LinkxBillingStatus> fetchBillingStatus() async {
    final data = await _get('/billing/me');
    return LinkxBillingStatus.fromJson(data);
  }

  Future<LinkxBillingStatus> purchasePlan(String planId) async {
    final data = await _post('/billing/checkout/$planId', {});
    return LinkxBillingStatus.fromJson(data);
  }

  LinkxRoom _roomFromResponse(Map<String, dynamic> data) {
    final room = data['room'];
    if (room is! Map) throw const LinkxApiException('Room is missing');
    return LinkxRoom.fromJson(Map<String, dynamic>.from(room));
  }

  Future<void> _uploadPhotos(List<XFile> photos) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/onboarding/photos'),
    );
    final token = await _token;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    for (final photo in photos) {
      request.files.add(
        await http.MultipartFile.fromPath('photos', photo.path),
      );
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LinkxApiException(_messageFromBody(body));
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(authenticated: authenticated),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _decode(response);
    } catch (error) {
      if (error is LinkxApiException) rethrow;
      throw const LinkxApiException(
        'Backend is not reachable. Please start the Linkx backend.',
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$path',
      ).replace(queryParameters: queryParameters);
      final response = await _httpClient
          .get(uri, headers: await _headers())
          .timeout(_requestTimeout);
      return _decode(response);
    } catch (error) {
      if (error is LinkxApiException) rethrow;
      throw const LinkxApiException(
        'Backend is not reachable. Please start the Linkx backend.',
      );
    }
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _httpClient
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _decode(response);
    } catch (error) {
      if (error is LinkxApiException) rethrow;
      throw const LinkxApiException(
        'Backend is not reachable. Please start the Linkx backend.',
      );
    }
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final response = await _httpClient
          .delete(Uri.parse('$baseUrl$path'), headers: await _headers())
          .timeout(_requestTimeout);
      return _decode(response);
    } catch (error) {
      if (error is LinkxApiException) rethrow;
      throw const LinkxApiException(
        'Backend is not reachable. Please start the Linkx backend.',
      );
    }
  }

  Future<Map<String, String>> _headers({bool authenticated = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await _token;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<String?> get _token async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(tokenKey);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data = _jsonMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LinkxApiException(data['message'] as String? ?? 'Request failed');
    }
    return data;
  }

  String _messageFromBody(String body) {
    final data = _jsonMap(body);
    return data['message'] as String? ?? 'Request failed';
  }

  Map<String, dynamic> _jsonMap(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return <String, dynamic>{};
  }
}

class LinkxCurrentUser {
  final String id;
  final String name;
  final String avatarUrl;
  final List<String> photoUrls;
  final String bio;
  final String identity;
  final DateTime? birthDate;
  final int? heightCm;
  final String educationLevel;
  final String lookingFor;
  final List<String> interests;
  final String children;
  final String smoking;
  final String location;
  final Map<String, bool> privacySettings;
  final Map<String, bool> notificationSettings;

  const LinkxCurrentUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.photoUrls,
    required this.bio,
    required this.identity,
    required this.birthDate,
    required this.heightCm,
    required this.educationLevel,
    required this.lookingFor,
    required this.interests,
    required this.children,
    required this.smoking,
    required this.location,
    required this.privacySettings,
    required this.notificationSettings,
  });

  factory LinkxCurrentUser.fromJson(Map<String, dynamic> json) {
    final photos = json['photos'];
    final photoUrls = photos is List
        ? photos
              .whereType<Map>()
              .map((photo) => photo['url'] as String? ?? '')
              .where((url) => url.isNotEmpty)
              .toList()
        : <String>[];
    final location = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : const <String, dynamic>{};

    return LinkxCurrentUser(
      id: json['_id'] as String? ?? '',
      name: json['firstName'] as String? ?? 'Linkx User',
      avatarUrl: photoUrls.isEmpty ? '' : photoUrls.first,
      photoUrls: photoUrls,
      bio: json['bio'] as String? ?? '',
      identity: json['identity'] as String? ?? '',
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      heightCm: (json['heightCm'] as num?)?.toInt(),
      educationLevel: json['educationLevel'] as String? ?? '',
      lookingFor: json['lookingFor'] as String? ?? '',
      interests:
          (json['happiness'] as List?)?.whereType<String>().toList() ??
          const [],
      children: json['children'] as String? ?? '',
      smoking: json['smoking'] as String? ?? '',
      location: location['label'] as String? ?? '',
      privacySettings: _boolSettings(json['privacySettings'], const {
        'discoverable': true,
        'showOnlineStatus': true,
        'showDistance': true,
        'showAge': true,
      }),
      notificationSettings: _boolSettings(json['notificationSettings'], const {
        'newMatches': true,
        'messages': true,
        'likes': true,
        'calls': true,
      }),
    );
  }

  static Map<String, bool> _boolSettings(
    dynamic value,
    Map<String, bool> defaults,
  ) {
    final settings = Map<String, bool>.from(defaults);
    if (value is Map) {
      for (final key in defaults.keys) {
        final setting = value[key];
        if (setting is bool) settings[key] = setting;
      }
    }
    return settings;
  }
}

class LinkxExploreUser {
  final String id;
  final String name;
  final int? age;
  final String imageUrl;
  final String location;
  final int? distanceMiles;
  final String lookingFor;
  final List<String> interests;
  final String identity;
  final String relationshipStatus;

  const LinkxExploreUser({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrl,
    required this.location,
    required this.distanceMiles,
    required this.lookingFor,
    required this.interests,
    required this.identity,
    required this.relationshipStatus,
  });

  factory LinkxExploreUser.fromJson(Map<String, dynamic> json) {
    return LinkxExploreUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Linkx User',
      age: json['age'] as int?,
      imageUrl: json['imageUrl'] as String? ?? '',
      location: json['location'] as String? ?? 'Nearby',
      distanceMiles: json['distanceMiles'] as int?,
      lookingFor: json['lookingFor'] as String? ?? '',
      interests:
          (json['interests'] as List?)
              ?.whereType<String>()
              .where((interest) => interest.trim().isNotEmpty)
              .toList() ??
          const [],
      identity: json['identity'] as String? ?? '',
      relationshipStatus: json['relationshipStatus'] as String? ?? 'none',
    );
  }
}

class LinkxRoomPage {
  final List<LinkxRoom> rooms;
  final int page;
  final bool hasMore;

  const LinkxRoomPage({
    required this.rooms,
    required this.page,
    required this.hasMore,
  });
}

class LinkxRoom {
  final String id;
  final String title;
  final String topic;
  final String privacy;
  final String status;
  final int maxParticipants;
  final int participantCount;
  final String zegoRoomId;
  final String? inviteCode;
  final bool isHost;
  final bool isJoined;
  final String? currentRole;
  final LinkxRoomUser host;
  final List<LinkxRoomMember> members;
  final DateTime? createdAt;

  const LinkxRoom({
    required this.id,
    required this.title,
    required this.topic,
    required this.privacy,
    required this.status,
    required this.maxParticipants,
    required this.participantCount,
    required this.zegoRoomId,
    required this.inviteCode,
    required this.isHost,
    required this.isJoined,
    required this.currentRole,
    required this.host,
    required this.members,
    required this.createdAt,
  });

  factory LinkxRoom.fromJson(Map<String, dynamic> json) {
    final host = json['host'] is Map
        ? Map<String, dynamic>.from(json['host'] as Map)
        : const <String, dynamic>{};
    return LinkxRoom(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled room',
      topic: json['topic'] as String? ?? '',
      privacy: json['privacy'] as String? ?? 'public',
      status: json['status'] as String? ?? 'ended',
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 12,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      zegoRoomId: json['zegoRoomId'] as String? ?? '',
      inviteCode: json['inviteCode'] as String?,
      isHost: json['isHost'] == true,
      isJoined: json['isJoined'] == true,
      currentRole: json['currentRole'] as String?,
      host: LinkxRoomUser.fromJson(host),
      members:
          (json['members'] as List?)
              ?.whereType<Map>()
              .map(
                (member) =>
                    LinkxRoomMember.fromJson(Map<String, dynamic>.from(member)),
              )
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class LinkxRoomMember {
  final String role;
  final DateTime? joinedAt;
  final LinkxRoomUser user;

  const LinkxRoomMember({
    required this.role,
    required this.joinedAt,
    required this.user,
  });

  factory LinkxRoomMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    return LinkxRoomMember(
      role: json['role'] as String? ?? 'listener',
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? ''),
      user: LinkxRoomUser.fromJson(user),
    );
  }
}

class LinkxRoomUser {
  final String id;
  final String name;
  final String imageUrl;

  const LinkxRoomUser({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory LinkxRoomUser.fromJson(Map<String, dynamic> json) {
    return LinkxRoomUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Linkx User',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}

class LinkxNotificationPage {
  final List<LinkxAppNotification> notifications;
  final int unreadCount;

  const LinkxNotificationPage({
    required this.notifications,
    required this.unreadCount,
  });
}

class LinkxAppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;

  const LinkxAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  factory LinkxAppNotification.fromJson(Map<String, dynamic> json) {
    return LinkxAppNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? 'Linkx',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
    );
  }
}

class LinkxEventPage {
  final List<LinkxEvent> events;
  final int page;
  final bool hasMore;

  const LinkxEventPage({
    required this.events,
    required this.page,
    required this.hasMore,
  });
}

class LinkxEvent {
  final String id;
  final String title;
  final String description;
  final String venue;
  final String coverImageUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final int capacity;
  final int priceCents;
  final String currency;
  final int attendeeCount;
  final bool isGoing;
  final String status;

  const LinkxEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.coverImageUrl,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.priceCents,
    required this.currency,
    required this.attendeeCount,
    required this.isGoing,
    required this.status,
  });

  factory LinkxEvent.fromJson(Map<String, dynamic> json) {
    return LinkxEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Linkx event',
      description: json['description'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      coverImageUrl: json['coverImageUrl'] as String? ?? '',
      startAt: DateTime.tryParse(json['startAt'] as String? ?? ''),
      endAt: DateTime.tryParse(json['endAt'] as String? ?? ''),
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      attendeeCount: (json['attendeeCount'] as num?)?.toInt() ?? 0,
      isGoing: json['isGoing'] == true,
      status: json['status'] as String? ?? 'published',
    );
  }
}

class LinkxBillingPlan {
  final String id;
  final String name;
  final int priceCents;
  final String currency;
  final List<String> features;

  const LinkxBillingPlan({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.currency,
    required this.features,
  });

  factory LinkxBillingPlan.fromJson(Map<String, dynamic> json) {
    return LinkxBillingPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      features:
          (json['features'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

class LinkxBillingStatus {
  final LinkxBillingPlan plan;
  final DateTime? expiresAt;

  const LinkxBillingStatus({required this.plan, required this.expiresAt});

  factory LinkxBillingStatus.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] is Map
        ? Map<String, dynamic>.from(json['plan'] as Map)
        : const <String, dynamic>{};
    final subscription = json['subscription'] is Map
        ? Map<String, dynamic>.from(json['subscription'] as Map)
        : const <String, dynamic>{};
    return LinkxBillingStatus(
      plan: LinkxBillingPlan.fromJson(plan),
      expiresAt: DateTime.tryParse(subscription['expiresAt'] as String? ?? ''),
    );
  }
}

class LinkxExplorePage {
  final List<LinkxExploreUser> users;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  const LinkxExplorePage({
    required this.users,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });
}

class LinkxMatchActionResult {
  final String action;
  final bool matched;

  const LinkxMatchActionResult({required this.action, required this.matched});

  factory LinkxMatchActionResult.fromJson(Map<String, dynamic> json) {
    return LinkxMatchActionResult(
      action: json['action'] as String? ?? '',
      matched: json['matched'] == true,
    );
  }
}

class LinkxMatchStatus {
  final bool matched;
  final bool blocked;
  final String? reaction;
  final bool likedByTarget;

  const LinkxMatchStatus({
    required this.matched,
    required this.blocked,
    required this.reaction,
    required this.likedByTarget,
  });

  factory LinkxMatchStatus.fromJson(Map<String, dynamic> json) {
    return LinkxMatchStatus(
      matched: json['matched'] == true,
      blocked: json['blocked'] == true,
      reaction: json['reaction'] as String?,
      likedByTarget: json['likedByTarget'] == true,
    );
  }
}

class LinkxOtpVerificationResult {
  final bool goHome;
  final String nextStep;

  const LinkxOtpVerificationResult({
    required this.goHome,
    required this.nextStep,
  });

  factory LinkxOtpVerificationResult.fromJson(Map<String, dynamic> json) {
    final nextStep = json['nextStep'] as String? ?? 'name';
    return LinkxOtpVerificationResult(
      goHome: nextStep == 'home',
      nextStep: nextStep,
    );
  }
}

class LinkxApiException implements Exception {
  final String message;

  const LinkxApiException(this.message);

  @override
  String toString() => message;
}
