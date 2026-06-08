import 'dart:async';
import 'dart:convert';

import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class LinkxChatService {
  LinkxChatService._();

  static final LinkxChatService instance = LinkxChatService._();

  final StreamController<LinkxChatMessage> _messageController =
      StreamController<LinkxChatMessage>.broadcast();
  final StreamController<void> _matchChangeController =
      StreamController<void>.broadcast();
  final StreamController<LinkxReadReceipt> _readReceiptController =
      StreamController<LinkxReadReceipt>.broadcast();
  final StreamController<LinkxTypingEvent> _typingController =
      StreamController<LinkxTypingEvent>.broadcast();
  final StreamController<LinkxPresenceEvent> _presenceController =
      StreamController<LinkxPresenceEvent>.broadcast();
  final StreamController<LinkxRoomSocketEvent> _roomController =
      StreamController<LinkxRoomSocketEvent>.broadcast();
  final StreamController<LinkxNotification> _notificationController =
      StreamController<LinkxNotification>.broadcast();
  final Set<String> _onlineUserIds = {};
  io.Socket? _socket;
  String? _connectedToken;
  Future<void>? _connectionFuture;

  Stream<LinkxChatMessage> get messages => _messageController.stream;
  Stream<void> get matchChanges => _matchChangeController.stream;
  Stream<LinkxReadReceipt> get readReceipts => _readReceiptController.stream;
  Stream<LinkxTypingEvent> get typingEvents => _typingController.stream;
  Stream<LinkxPresenceEvent> get presenceEvents => _presenceController.stream;
  Stream<LinkxRoomSocketEvent> get roomEvents => _roomController.stream;
  Stream<LinkxNotification> get notifications => _notificationController.stream;

  bool isOnline(String userId) => _onlineUserIds.contains(userId);

  Future<void> connect() async {
    final token = await _authToken;
    if (token == null || token.isEmpty) {
      throw const LinkxApiException('Please sign in to use chat');
    }
    if (_socket?.connected == true && _connectedToken == token) return;

    final activeConnection = _connectionFuture;
    if (activeConnection != null && _connectedToken == token) {
      return activeConnection;
    }

    _connectedToken = token;
    final connectionFuture = _connectWithToken(token);
    _connectionFuture = connectionFuture;
    try {
      await connectionFuture;
    } finally {
      if (identical(_connectionFuture, connectionFuture)) {
        _connectionFuture = null;
      }
    }
  }

  Future<void> _connectWithToken(String token) async {
    _disposeSocket();
    _clearPresence();
    final socket = io.io(
      _socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .enableForceNew()
          .disableMultiplex()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;
    socket.on('chat:message', (data) {
      if (data is Map) {
        _messageController.add(
          LinkxChatMessage.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });
    socket.on('match:created', (_) {
      _matchChangeController.add(null);
      socket.emit('chat:presence:request');
    });
    socket.on('match:removed', (data) {
      if (data is Map) {
        final userIds = data['userIds'];
        if (userIds is List) {
          for (final userId in userIds.whereType<String>()) {
            _onlineUserIds.remove(userId);
          }
          _presenceController.add(
            const LinkxPresenceEvent(userId: '', isOnline: false),
          );
        }
      }
      _matchChangeController.add(null);
    });
    socket.on('chat:read', (data) {
      if (data is Map) {
        _readReceiptController.add(
          LinkxReadReceipt.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });
    socket.on('chat:typing', (data) {
      if (data is Map) {
        _typingController.add(
          LinkxTypingEvent.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });
    socket.on('chat:presence', (data) {
      if (data is! Map) return;
      final event = LinkxPresenceEvent.fromJson(
        Map<String, dynamic>.from(data),
      );
      _setPresence(event.userId, event.isOnline);
    });
    socket.on('chat:presence:snapshot', (data) {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final onlineUserIds = map['onlineUserIds'];
      _onlineUserIds
        ..clear()
        ..addAll(
          onlineUserIds is List
              ? onlineUserIds.whereType<String>()
              : const <String>[],
        );
      _presenceController.add(
        const LinkxPresenceEvent(userId: '', isOnline: false),
      );
    });
    for (final eventName in [
      'room:updated',
      'room:ended',
      'room:removed',
      'room:list:updated',
    ]) {
      socket.on(eventName, (data) {
        if (data is Map) {
          _roomController.add(
            LinkxRoomSocketEvent.fromJson(
              eventName,
              Map<String, dynamic>.from(data),
            ),
          );
        }
      });
    }
    socket.on('notification:new', (data) {
      if (data is Map) {
        _notificationController.add(
          LinkxNotification.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });
    socket.connect();
  }

  Future<List<LinkxConversation>> fetchConversations() async {
    final data = await _get('/chat/conversations');
    final conversations = data['conversations'];
    if (conversations is! List) return const [];
    return conversations
        .whereType<Map>()
        .map(
          (item) => LinkxConversation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<LinkxMessagePage> fetchMessagePage(
    String userId, {
    String? before,
    int limit = 200,
  }) async {
    final query = <String, String>{
      'limit': '${limit.clamp(1, 200)}',
      if (before != null && before.isNotEmpty) 'before': before,
    };
    final data = await _get('/chat/messages/$userId', query: query);
    final messages = data['messages'];
    final pagination = data['pagination'] is Map
        ? Map<String, dynamic>.from(data['pagination'] as Map)
        : const <String, dynamic>{};
    return LinkxMessagePage(
      messages: messages is List
          ? messages
                .whereType<Map>()
                .map(
                  (item) => LinkxChatMessage.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      hasMore: pagination['hasMore'] == true,
      nextCursor: pagination['nextCursor'] as String?,
    );
  }

  Future<LinkxChatMessage> sendMessage({
    required String recipientId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw const LinkxApiException('Message cannot be empty');
    }

    await connect();
    final socket = _socket;
    if (socket?.connected == true) {
      final completer = Completer<LinkxChatMessage>();
      socket!.emitWithAck(
        'chat:send',
        {'recipientId': recipientId, 'text': cleanText},
        ack: (data) {
          if (data is! Map) {
            completer.completeError(
              const LinkxApiException('Invalid chat response'),
            );
            return;
          }
          final result = Map<String, dynamic>.from(data);
          if (result['ok'] != true || result['message'] is! Map) {
            completer.completeError(
              LinkxApiException(
                result['message'] as String? ?? 'Unable to send message',
              ),
            );
            return;
          }
          completer.complete(
            LinkxChatMessage.fromJson(
              Map<String, dynamic>.from(result['message'] as Map),
            ),
          );
        },
      );
      return completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () =>
            throw const LinkxApiException('Chat server did not respond'),
      );
    }

    final data = await _post('/chat/messages', {
      'recipientId': recipientId,
      'text': cleanText,
    });
    final message = data['message'];
    if (message is! Map) {
      throw const LinkxApiException('Invalid chat response');
    }
    return LinkxChatMessage.fromJson(Map<String, dynamic>.from(message));
  }

  Future<void> markRead(String userId) async {
    await connect();
    final socket = _socket;
    if (socket?.connected == true) {
      socket!.emitWithAck('chat:read', {'userId': userId});
      return;
    }
    await _post('/chat/messages/$userId/read', const {});
  }

  Future<void> setTyping({
    required String recipientId,
    required bool isTyping,
  }) async {
    await connect();
    _socket?.emit('chat:typing', {
      'recipientId': recipientId,
      'isTyping': isTyping,
    });
  }

  Future<void> subscribeRoom(String roomId) async {
    await connect();
    _socket?.emitWithAck('room:subscribe', {'roomId': roomId});
  }

  void unsubscribeRoom(String roomId) {
    _socket?.emit('room:unsubscribe', {'roomId': roomId});
  }

  void disconnect() {
    _disposeSocket();
    _connectedToken = null;
    _connectionFuture = null;
    _clearPresence();
  }

  void _disposeSocket() {
    final socket = _socket;
    _socket = null;
    socket?.clearListeners();
    socket?.disconnect();
    socket?.dispose();
  }

  void _setPresence(String userId, bool isOnline) {
    if (userId.isEmpty) return;
    if (isOnline) {
      _onlineUserIds.add(userId);
    } else {
      _onlineUserIds.remove(userId);
    }
    _presenceController.add(
      LinkxPresenceEvent(userId: userId, isOnline: isOnline),
    );
  }

  void _clearPresence() {
    if (_onlineUserIds.isEmpty) return;
    _onlineUserIds.clear();
    _presenceController.add(
      const LinkxPresenceEvent(userId: '', isOnline: false),
    );
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '${LinkxApiClient.baseUrl}$path',
    ).replace(queryParameters: query);
    final response = await http
        .get(uri, headers: await _headers)
        .timeout(const Duration(seconds: 8));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('${LinkxApiClient.baseUrl}$path'),
          headers: await _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    return _decode(response);
  }

  Future<Map<String, String>> get _headers async {
    final token = await _authToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> get _authToken async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(LinkxApiClient.tokenKey);
  }

  String get _socketBaseUrl {
    final apiUrl = LinkxApiClient.baseUrl;
    return apiUrl.endsWith('/api')
        ? apiUrl.substring(0, apiUrl.length - 4)
        : apiUrl;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LinkxApiException(data['message'] as String? ?? 'Request failed');
    }
    return data;
  }
}

class LinkxConversation {
  final String id;
  final String userId;
  final String userName;
  final String userImageUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const LinkxConversation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory LinkxConversation.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    return LinkxConversation(
      id: json['id'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      userName: user['name'] as String? ?? 'Linkx User',
      userImageUrl: user['imageUrl'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt: DateTime.tryParse(json['lastMessageAt'] as String? ?? ''),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class LinkxMessagePage {
  final List<LinkxChatMessage> messages;
  final bool hasMore;
  final String? nextCursor;

  const LinkxMessagePage({
    required this.messages,
    required this.hasMore,
    required this.nextCursor,
  });
}

class LinkxChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime? createdAt;
  final DateTime? readAt;

  const LinkxChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
    required this.readAt,
  });

  factory LinkxChatMessage.fromJson(Map<String, dynamic> json) {
    return LinkxChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
    );
  }

  LinkxChatMessage copyWith({DateTime? readAt}) {
    return LinkxChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      recipientId: recipientId,
      text: text,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

class LinkxReadReceipt {
  final String conversationId;
  final String readerId;
  final DateTime? readAt;

  const LinkxReadReceipt({
    required this.conversationId,
    required this.readerId,
    required this.readAt,
  });

  factory LinkxReadReceipt.fromJson(Map<String, dynamic> json) {
    return LinkxReadReceipt(
      conversationId: json['conversationId'] as String? ?? '',
      readerId: json['readerId'] as String? ?? '',
      readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
    );
  }
}

class LinkxTypingEvent {
  final String userId;
  final bool isTyping;

  const LinkxTypingEvent({required this.userId, required this.isTyping});

  factory LinkxTypingEvent.fromJson(Map<String, dynamic> json) {
    return LinkxTypingEvent(
      userId: json['userId'] as String? ?? '',
      isTyping: json['isTyping'] == true,
    );
  }
}

class LinkxPresenceEvent {
  final String userId;
  final bool isOnline;

  const LinkxPresenceEvent({required this.userId, required this.isOnline});

  factory LinkxPresenceEvent.fromJson(Map<String, dynamic> json) {
    return LinkxPresenceEvent(
      userId: json['userId'] as String? ?? '',
      isOnline: json['isOnline'] == true,
    );
  }
}

class LinkxRoomSocketEvent {
  final String type;
  final String roomId;

  const LinkxRoomSocketEvent({required this.type, required this.roomId});

  factory LinkxRoomSocketEvent.fromJson(
    String type,
    Map<String, dynamic> json,
  ) {
    return LinkxRoomSocketEvent(
      type: type,
      roomId: json['roomId'] as String? ?? '',
    );
  }
}

class LinkxNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? createdAt;

  const LinkxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  factory LinkxNotification.fromJson(Map<String, dynamic> json) {
    return LinkxNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? 'Linkx',
      body: json['body'] as String? ?? '',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
