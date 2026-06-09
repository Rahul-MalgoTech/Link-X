import 'dart:math' as math;
import 'dart:async';

import 'package:bossy/BossyScreens/HomeScreens/BossyBottomNavBar.dart';
import 'package:bossy/BossyScreens/LoginScreens/LoginScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:bossy/BossyServices/linkx_chat_service.dart';
import 'package:bossy/BossyServices/linkx_call_service.dart';
import 'package:bossy/BossyServices/linkx_room_audio_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class BossyHomeShell extends StatefulWidget {
  const BossyHomeShell({super.key});

  @override
  State<BossyHomeShell> createState() => _BossyHomeShellState();
}

class _BossyHomeShellState extends State<BossyHomeShell> {
  int _selectedIndex = 0;
  bool _hasLikes = false;
  bool _hasUnreadChats = false;
  StreamSubscription<LinkxChatMessage>? _messageSubscription;
  StreamSubscription<void>? _matchSubscription;
  StreamSubscription<LinkxReadReceipt>? _readReceiptSubscription;

  @override
  void initState() {
    super.initState();
    LinkxCallService.instance.initializeForSignedInUser().catchError((error) {
      debugPrint('Linkx incoming-call initialization failed: $error');
    });
    _refreshNavigationIndicators();
    LinkxChatService.instance.connect().catchError((_) {});
    _messageSubscription = LinkxChatService.instance.messages.listen((_) {
      _refreshNavigationIndicators();
    });
    _matchSubscription = LinkxChatService.instance.matchChanges.listen((_) {
      _refreshNavigationIndicators();
    });
    _readReceiptSubscription = LinkxChatService.instance.readReceipts.listen(
      (_) => _refreshNavigationIndicators(),
    );
  }

  Future<void> _refreshNavigationIndicators() async {
    try {
      final results = await Future.wait<dynamic>([
        LinkxApiClient().fetchReceivedLikes(limit: 1),
        LinkxChatService.instance.fetchConversations(),
      ]);
      if (!mounted) return;
      final likes = results[0] as LinkxLikesPage;
      final conversations = results[1] as List<LinkxConversation>;
      setState(() {
        _hasLikes = likes.total > 0;
        _hasUnreadChats = conversations.any(
          (conversation) => conversation.unreadCount > 0,
        );
      });
    } catch (_) {}
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    if (index == 3 || index == 4) {
      _refreshNavigationIndicators();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _matchSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFAF7F8),
      body: Stack(
        children: [
          Positioned.fill(child: _buildPage()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BossyBottomNavBar(
              selectedIndex: _selectedIndex,
              showLikesIndicator: _hasLikes,
              showChatIndicator: _hasUnreadChats,
              onTap: _selectPage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    return IndexedStack(
      index: _selectedIndex,
      children: const [
        _HomePage(),
        _ExplorePage(),
        _PeoplePage(),
        _LikesPage(),
        _ChatListPage(),
        _UserProfilePage(),
      ],
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late Future<LinkxRoomPage> _roomsFuture;
  late Future<_HomeInterestProfilesResult> _interestProfilesFuture;
  StreamSubscription<LinkxRoomSocketEvent>? _roomSubscription;

  @override
  void initState() {
    super.initState();
    _roomsFuture = LinkxApiClient().fetchRooms(limit: 50);
    _interestProfilesFuture = _loadInterestProfiles();
    LinkxChatService.instance.connect().catchError((_) {});
    _roomSubscription = LinkxChatService.instance.roomEvents.listen((event) {
      if (event.type == 'room:list:updated' && mounted) _refreshRooms();
    });
  }

  Future<void> _refreshRooms() async {
    final rooms = LinkxApiClient().fetchRooms(limit: 50);
    final profiles = _loadInterestProfiles();
    setState(() {
      _roomsFuture = rooms;
      _interestProfilesFuture = profiles;
    });
    await Future.wait([rooms, profiles]);
  }

  Future<_HomeInterestProfilesResult> _loadInterestProfiles() async {
    final user = await LinkxApiClient().fetchCurrentUser();
    final interests = user.interests
        .map((interest) => interest.trim())
        .where((interest) => interest.isNotEmpty)
        .toList();
    if (interests.isEmpty) {
      return _HomeInterestProfilesResult(
        interests: interests,
        profiles: const [],
      );
    }
    final page = await LinkxApiClient().fetchExploreUsers(
      limit: 6,
      interests: interests,
      excludeReacted: true,
    );
    return _HomeInterestProfilesResult(
      interests: interests,
      profiles: page.users
          .where((user) => user.imageUrl.trim().isNotEmpty)
          .map(_ProfileData.fromExploreUser)
          .toList(),
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFFAAE2B),
      onRefresh: _refreshRooms,
      child: FutureBuilder<LinkxRoomPage>(
        future: _roomsFuture,
        builder: (context, snapshot) {
          final rooms = snapshot.data?.rooms ?? const <LinkxRoom>[];
          final publicCount = rooms
              .where((room) => room.privacy == 'public')
              .length;
          final privateCount = rooms
              .where((room) => room.privacy == 'private')
              .length;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _BossyHeader(),
                        const SizedBox(height: 10),
                        const _HomeHeroBanner(),
                        const SizedBox(height: 20),
                        _HomeSectionHeader(
                          title: 'Rooms',
                          action: 'Create',
                          onAction: () async {
                            final room = await Navigator.of(context)
                                .push<LinkxRoom>(
                                  MaterialPageRoute(
                                    builder: (_) => const _CreateRoomPage(),
                                  ),
                                );
                            if (room != null && context.mounted) {
                              await _refreshRooms();
                              if (!context.mounted) return;
                              await _openRoomLobby(context, room);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _RoomsRow(
                          publicCount: publicCount,
                          privateCount: privateCount,
                        ),
                        if (snapshot.hasError) ...[
                          const SizedBox(height: 10),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const _HomeSectionHeader(title: 'Events'),
                        const SizedBox(height: 12),
                        const _EventsRow(),
                        const SizedBox(height: 20),
                        _HomeInterestProfilesSection(
                          future: _interestProfilesFuture,
                          onRefresh: _refreshRooms,
                        ),
                        const SizedBox(height: 116),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeInterestProfilesResult {
  final List<String> interests;
  final List<_ProfileData> profiles;

  const _HomeInterestProfilesResult({
    required this.interests,
    required this.profiles,
  });
}

class _HomeInterestProfilesSection extends StatelessWidget {
  final Future<_HomeInterestProfilesResult> future;
  final Future<void> Function() onRefresh;

  const _HomeInterestProfilesSection({
    required this.future,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeInterestProfilesResult>(
      future: future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final primaryInterest = result?.interests.isNotEmpty == true
            ? result!.interests.first
            : 'your interests';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeSectionHeader(
              title: 'People into $primaryInterest',
              width: 360,
              action: 'Refresh',
              onAction: () => unawaited(onRefresh()),
            ),
            const SizedBox(height: 8),
            _InterestMatchBanner(interests: result?.interests ?? const []),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const _InterestProfileLoading()
            else if (snapshot.hasError)
              _InlineHomeError(
                message: snapshot.error.toString(),
                action: onRefresh,
              )
            else if (result == null || result.interests.isEmpty)
              _InterestEmptyState(
                icon: Icons.interests_rounded,
                title: 'Choose interests to personalize Home',
                message:
                    'Add interests like cooking, music, travel, or fitness in your profile to unlock tailored people here.',
                onTap: onRefresh,
              )
            else if (result.profiles.isEmpty)
              _InterestEmptyState(
                icon: Icons.person_search_rounded,
                title: 'No ${result.interests.first} people yet',
                message:
                    'When new users share your interests, they will appear here first.',
                onTap: onRefresh,
              )
            else
              _ProfileGrid(profiles: result.profiles, homeScale: false),
          ],
        );
      },
    );
  }
}

class _InterestMatchBanner extends StatelessWidget {
  final List<String> interests;

  const _InterestMatchBanner({required this.interests});

  @override
  Widget build(BuildContext context) {
    final visible = interests.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1DB), Color(0xFFFFFBF3)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFFAAE2B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              visible.isEmpty
                  ? 'Home will become smarter after you add interests.'
                  : 'Curated from your interests: ${visible.join(', ')}',
              style: const TextStyle(
                color: Color(0xFF403027),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestProfileLoading extends StatelessWidget {
  const _InterestProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator(color: Color(0xFFFAAE2B))),
    );
  }
}

class _InterestEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onTap;

  const _InterestEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00473E), size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF777370),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => unawaited(onTap()),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _ExplorePage extends StatefulWidget {
  const _ExplorePage();

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  final TextEditingController _searchController = TextEditingController();
  late Future<LinkxExplorePage> _profilesFuture;
  late Future<LinkxApprovedHostPage> _hostsFuture;
  String? _identity;
  int _minAge = 18;
  int _maxAge = 80;
  int _maxDistance = 100;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _loadProfiles();
    _hostsFuture = _loadHosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<LinkxExplorePage> _loadProfiles() {
    return LinkxApiClient().fetchExploreUsers(
      page: _page,
      limit: 12,
      identity: _identity,
      minAge: _minAge,
      maxAge: _maxAge,
      maxDistance: _maxDistance,
      search: _searchController.text,
    );
  }

  Future<LinkxApprovedHostPage> _loadHosts() {
    return LinkxApiClient().fetchApprovedHosts(limit: 12);
  }

  Future<void> _refreshProfiles() async {
    final nextProfiles = _loadProfiles();
    final nextHosts = _loadHosts();
    setState(() {
      _profilesFuture = nextProfiles;
      _hostsFuture = nextHosts;
    });
    await Future.wait([_profilesFuture, _hostsFuture]);
  }

  Future<void> _applySearch() async {
    _page = 1;
    await _refreshProfiles();
  }

  Future<void> _changeIdentity(String? identity) async {
    setState(() {
      _identity = identity;
      _page = 1;
      _profilesFuture = _loadProfiles();
    });
    await _profilesFuture;
  }

  Future<void> _changePage(int page) async {
    setState(() {
      _page = page;
      _profilesFuture = _loadProfiles();
    });
    await _profilesFuture;
  }

  Future<void> _showFilters() async {
    var ageRange = RangeValues(_minAge.toDouble(), _maxAge.toDouble());
    var distance = _maxDistance.toDouble();
    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discovery filters',
                    style: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Age ${ageRange.start.round()} - ${ageRange.end.round()}',
                  ),
                  RangeSlider(
                    values: ageRange,
                    min: 18,
                    max: 80,
                    divisions: 62,
                    activeColor: const Color(0xFFFAAE2B),
                    onChanged: (value) {
                      setModalState(() => ageRange = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('Maximum distance: ${distance.round()} miles'),
                  Slider(
                    value: distance,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    activeColor: const Color(0xFF00473E),
                    onChanged: (value) {
                      setModalState(() => distance = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFAAE2B),
                      ),
                      child: const Text('Apply filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (applied != true || !mounted) return;
    setState(() {
      _minAge = ageRange.start.round();
      _maxAge = ageRange.end.round();
      _maxDistance = distance.round();
      _page = 1;
      _profilesFuture = _loadProfiles();
    });
    await _profilesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFFAAE2B),
      onRefresh: _refreshProfiles,
      child: FutureBuilder<LinkxExplorePage>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          final result = snapshot.data;
          final profiles =
              result?.users
                  .where((user) => user.imageUrl.trim().isNotEmpty)
                  .map(_ProfileData.fromExploreUser)
                  .toList() ??
              const <_ProfileData>[];
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _BossyHeader(notificationSize: 24),
                        const SizedBox(height: 18),
                        _SearchAndFilter(
                          controller: _searchController,
                          onSearch: _applySearch,
                          onFilter: _showFilters,
                        ),
                        const SizedBox(height: 16),
                        _GenderToggle(
                          selectedIdentity: _identity,
                          onChanged: _changeIdentity,
                        ),
                        const SizedBox(height: 20),
                        const _ExploreSectionHeader(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Approved hosts',
                          action: 'Staff',
                        ),
                        const SizedBox(height: 12),
                        _ApprovedHostsStrip(
                          future: _hostsFuture,
                          onRefresh: _refreshProfiles,
                        ),
                        const SizedBox(height: 22),
                        const _ExploreSectionHeader(
                          icon: Icons.local_fire_department_outlined,
                          title: 'Profiles from Linkx',
                          action: 'Live',
                        ),
                        const SizedBox(height: 12),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const _ExploreLoadingState()
                        else if (snapshot.hasError)
                          _ExploreMessageState(
                            icon: Icons.cloud_off_rounded,
                            title: 'Unable to load profiles',
                            message: snapshot.error.toString(),
                            buttonText: 'Retry',
                            onTap: _refreshProfiles,
                          )
                        else if (profiles.isEmpty)
                          _ExploreMessageState(
                            icon: Icons.person_search_rounded,
                            title: 'No users found',
                            message:
                                'Completed users with profile photos will appear here.',
                            buttonText: 'Refresh',
                            onTap: _refreshProfiles,
                          )
                        else ...[
                          _ProfileGrid(profiles: profiles, homeScale: false),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: _page > 1
                                    ? () => _changePage(_page - 1)
                                    : null,
                                child: const Text('Previous'),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Page ${result?.page ?? _page}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton(
                                onPressed: result?.hasMore == true
                                    ? () => _changePage(_page + 1)
                                    : null,
                                child: const Text('Next'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 116),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ApprovedHostsStrip extends StatelessWidget {
  final Future<LinkxApprovedHostPage> future;
  final Future<void> Function() onRefresh;

  const _ApprovedHostsStrip({required this.future, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkxApprovedHostPage>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const _ApprovedHostSkeleton(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _ExploreMessageState(
            icon: Icons.workspace_premium_outlined,
            title: 'Unable to load hosts',
            message: snapshot.error.toString(),
            buttonText: 'Retry',
            onTap: onRefresh,
          );
        }
        final hosts = snapshot.data?.hosts ?? const <LinkxApprovedHost>[];
        if (hosts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE7E2E4)),
            ),
            child: const Text(
              'Approved Linkx hosts will appear here after admin approval.',
              style: TextStyle(
                color: Color(0xFF777370),
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.35,
              ),
            ),
          );
        }
        return SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: hosts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) =>
                _ApprovedHostCard(host: hosts[index]),
          ),
        );
      },
    );
  }
}

class _ApprovedHostCard extends StatelessWidget {
  final LinkxApprovedHost host;

  const _ApprovedHostCard({required this.host});

  @override
  Widget build(BuildContext context) {
    final imageUrl = host.avatarUrl.isNotEmpty
        ? host.avatarUrl
        : host.media?.url ?? '';
    final chips = [...host.topics.take(2), ...host.languages.take(1)];
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 116,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(imageUrl, fit: BoxFit.cover)
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFE3A5), Color(0xFFDCEFE9)],
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'APPROVED HOST',
                      style: TextStyle(
                        color: Color(0xFF00473E),
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F1D1C),
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  host.bio.isEmpty ? 'Premium room and event host' : host.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF777370),
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4DE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          chip,
                          style: const TextStyle(
                            color: Color(0xFF9B6807),
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovedHostSkeleton extends StatelessWidget {
  const _ApprovedHostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFAAE2B),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _PeoplePage extends StatefulWidget {
  const _PeoplePage();

  @override
  State<_PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<_PeoplePage> {
  late Future<LinkxExplorePage> _peopleFuture;
  bool _acting = false;
  bool _profileExpanded = false;
  bool _showLikeBurst = false;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _peopleFuture = _loadPeople();
  }

  Future<LinkxExplorePage> _loadPeople() {
    return LinkxApiClient().fetchExploreUsers(
      page: 1,
      limit: 12,
      excludeReacted: true,
    );
  }

  Future<void> _refresh() async {
    final nextPeople = _loadPeople();
    setState(() {
      _peopleFuture = nextPeople;
      _profileExpanded = false;
      _showLikeBurst = false;
      _dragOffset = Offset.zero;
    });
    await _peopleFuture;
  }

  Future<void> _react(_ProfileData profile, {required bool liked}) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final result = liked
          ? await LinkxApiClient().likeUser(profile.id)
          : await LinkxApiClient().passUser(profile.id);
      if (!mounted) return;
      setState(() {
        _profileExpanded = false;
        _showLikeBurst = false;
        _dragOffset = Offset.zero;
      });
      if (result.matched) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("It's a match!"),
            content: Text(
              'You and ${profile.name} liked each other. You can now chat or call.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showProfileAction(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _acting = false;
          _showLikeBurst = false;
        });
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_acting) return;
    setState(() => _dragOffset += details.delta);
  }

  Future<void> _handlePanEnd(_ProfileData profile) async {
    if (_acting) return;
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;
    if (dy < -90 && dy.abs() > dx.abs()) {
      setState(() {
        _dragOffset = Offset.zero;
        _profileExpanded = true;
      });
      return;
    }
    if (dx > 100) {
      setState(() {
        _showLikeBurst = true;
        _dragOffset = const Offset(150, -8);
      });
      await Future<void>.delayed(const Duration(milliseconds: 430));
      await _react(profile, liked: true);
      return;
    }
    if (dx < -100) {
      setState(() => _dragOffset = Offset.zero);
      await _react(profile, liked: false);
      return;
    }
    setState(() => _dragOffset = Offset.zero);
  }

  Future<void> _startProfileCall(
    _ProfileData profile, {
    required bool video,
  }) async {
    if (!profile.isMatched) {
      _showProfileAction(
        context,
        'You can only ${video ? 'video call' : 'call'} after you both like each other.',
      );
      return;
    }
    final result = await LinkxCallService.instance.startCall(
      targetUserId: profile.id,
      targetUserName: profile.name,
      isVideoCall: video,
    );
    if (!mounted || result.success) return;
    _showProfileAction(context, result.message ?? 'Unable to start call.');
  }

  void _openProfileChat(_ProfileData profile) {
    if (!profile.isMatched) {
      _showProfileAction(
        context,
        'You can only chat after you both like each other.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChatDetailPage(
          chat: _ChatData(
            profile.image,
            profile.name,
            'Say hi and start the conversation.',
            'now',
            userId: profile.id,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          children: [
            const _PeopleHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<LinkxExplorePage>(
                future: _peopleFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFAAE2B),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ExploreMessageState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load people',
                      message: snapshot.error.toString(),
                      buttonText: 'Retry',
                      onTap: _refresh,
                    );
                  }

                  final users = snapshot.data?.users ?? const [];
                  if (users.isEmpty) {
                    return _ExploreMessageState(
                      icon: Icons.done_all_rounded,
                      title: 'You are all caught up',
                      message:
                          'New profiles will appear here when they become available.',
                      buttonText: 'Refresh',
                      onTap: _refresh,
                    );
                  }

                  final profile = _ProfileData.fromExploreUser(users.first);
                  return RefreshIndicator(
                    color: const Color(0xFFFAAE2B),
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(bottom: 112),
                      child: Column(
                        children: [
                          GestureDetector(
                            onPanUpdate: _handlePanUpdate,
                            onPanEnd: (_) => _handlePanEnd(profile),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              transform: Matrix4.identity()
                                ..translateByDouble(
                                  _dragOffset.dx,
                                  _dragOffset.dy,
                                  0,
                                  1,
                                )
                                ..rotateZ(_dragOffset.dx / 900),
                              child: _PeopleSwipeCard(
                                profile: profile,
                                expanded: _profileExpanded,
                                dragOffset: _dragOffset,
                                showLikeBurst: _showLikeBurst,
                                onExpand: () =>
                                    setState(() => _profileExpanded = true),
                                onCollapse: () =>
                                    setState(() => _profileExpanded = false),
                                onCall: () =>
                                    _startProfileCall(profile, video: false),
                                onVideo: () =>
                                    _startProfileCall(profile, video: true),
                                onChat: () => _openProfileChat(profile),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Swipe left to pass • right to like • up for profile',
                            style: TextStyle(
                              color: Color(0xFF8A8581),
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleSwipeCard extends StatelessWidget {
  final _ProfileData profile;
  final bool expanded;
  final Offset dragOffset;
  final bool showLikeBurst;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onCall;
  final VoidCallback onVideo;
  final VoidCallback onChat;

  const _PeopleSwipeCard({
    required this.profile,
    required this.expanded,
    required this.dragOffset,
    required this.showLikeBurst,
    required this.onExpand,
    required this.onCollapse,
    required this.onCall,
    required this.onVideo,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final passOpacity = (-dragOffset.dx / 120).clamp(0.0, 1.0);
    final likeOpacity = showLikeBurst
        ? 1.0
        : (dragOffset.dx / 120).clamp(0.0, 1.0);
    final upOpacity = (-dragOffset.dy / 100).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image(
                  image: _linkxImageProvider(profile.image),
                  width: double.infinity,
                  height: expanded ? 360 : 438,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 76,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: likeOpacity,
                      child: Transform.scale(
                        scale: showLikeBurst
                            ? 1.22
                            : 0.76 + (likeOpacity * 0.34),
                        child: const Center(child: _SwipeHeartStamp()),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 18,
                  child: Opacity(
                    opacity: passOpacity,
                    child: const _SwipeStamp(
                      text: 'PASS',
                      color: Color(0xFFFF4778),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 18,
                  child: Opacity(
                    opacity: upOpacity,
                    child: const Center(
                      child: _SwipeStamp(
                        text: 'PROFILE',
                        color: Color(0xFF00473E),
                      ),
                    ),
                  ),
                ),
                if (!expanded)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _CardCircleButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      color: const Color(0xFF00473E),
                      onTap: onExpand,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PeopleProfileSummary(profile: profile),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(height: 0),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _InlineContactActions(
                          matched: profile.isMatched,
                          onCall: onCall,
                          onVideo: onVideo,
                          onChat: onChat,
                        ),
                        const SizedBox(height: 16),
                        _InlineProfileDetails(profile: profile),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            onPressed: onCollapse,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            label: const Text('Hide details'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleProfileSummary extends StatelessWidget {
  final _ProfileData profile;

  const _PeopleProfileSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                profile.age == null
                    ? profile.name
                    : '${profile.name}, ${profile.age}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF20D56B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 24,
              color: Color(0xFF679C95),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                profile.locationLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF777370),
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineContactActions extends StatelessWidget {
  final bool matched;
  final VoidCallback onCall;
  final VoidCallback onVideo;
  final VoidCallback onChat;

  const _InlineContactActions({
    required this.matched,
    required this.onCall,
    required this.onVideo,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!matched) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1DB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Like each other to unlock chat, call, and video call.',
              style: TextStyle(
                color: Color(0xFF7A4A00),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _ContactActionButton(
                label: 'Call',
                icon: Icons.call_rounded,
                color: matched
                    ? const Color(0xFF00473E)
                    : const Color(0xFFB7B7B7),
                onTap: onCall,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ContactActionButton(
                label: 'Video',
                icon: Icons.videocam_rounded,
                color: matched
                    ? const Color(0xFFFAAE2B)
                    : const Color(0xFFCFCFCF),
                onTap: onVideo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ContactActionButton(
                label: 'Chat',
                icon: Icons.chat_bubble_rounded,
                color: matched
                    ? const Color(0xFFFF3F7A)
                    : const Color(0xFFB7B7B7),
                onTap: onChat,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineProfileDetails extends StatelessWidget {
  final _ProfileData profile;

  const _InlineProfileDetails({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _ProfileInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Identity',
            value: profile.identity.isEmpty ? 'Not shared' : profile.identity,
          ),
          const SizedBox(height: 12),
          _ProfileInfoRow(
            icon: Icons.favorite_border_rounded,
            label: 'Looking for',
            value: profile.lookingFor.isEmpty
                ? 'Meaningful connection'
                : profile.lookingFor,
          ),
          const SizedBox(height: 12),
          _ProfileInfoRow(
            icon: Icons.interests_rounded,
            label: 'Interests',
            value: profile.interests.isEmpty
                ? 'Not shared yet'
                : profile.interests.take(4).join(', '),
          ),
        ],
      ),
    );
  }
}

class _CardCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CardCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: color)),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  final String text;
  final Color color;

  const _SwipeStamp({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'Bricolage Grotesque',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _SwipeHeartStamp extends StatelessWidget {
  const _SwipeHeartStamp();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4778),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4778).withValues(alpha: 0.35),
            blurRadius: 34,
            spreadRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 58),
    );
  }
}

class _PeopleHeader extends StatelessWidget {
  const _PeopleHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const _LinkxHeaderLogo(width: 77, height: 16),
        _FigmaBellIcon(size: 24, color: const Color(0xFF00473E)),
      ],
    );
  }
}

class _PeopleHeroCard extends StatelessWidget {
  const _PeopleHeroCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, 362.0)
            : 362.0;
        final scale = width / 362;
        final height = 581 * scale;

        return SizedBox(
          width: width,
          height: height,
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale: scale,
            child: const SizedBox(
              width: 362,
              height: 581,
              child: _PeopleHeroCardContent(),
            ),
          ),
        );
      },
    );
  }
}

class _PeopleHeroCardContent extends StatelessWidget {
  const _PeopleHeroCardContent();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/people/eleonora_main.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(left: 10, top: 6, child: _GlassChip(text: 'She likes you')),
        Positioned(
          left: 10,
          bottom: 96,
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFAAE2B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _FigmaFlameIcon(size: 10, color: Colors.white),
                const SizedBox(width: 5),
                const Text(
                  'PREMIUM',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Text(
                    'Eleonora, 22',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1.12,
                    ),
                  ),
                  SizedBox(width: 6),
                  _FigmaVerifiedIcon(size: 18),
                ],
              ),
              const SizedBox(height: 5),
              _PeopleFact(
                icon: _FigmaLocationIcon(size: 14, color: Colors.white),
                text: 'Ion Orchard, Singapore',
              ),
              const SizedBox(height: 5),
              _PeopleFact(
                icon: _FigmaBriefcaseIcon(size: 14, color: Colors.white),
                text: 'Chartered Accountant, 2024',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FigmaPainterIcon extends StatelessWidget {
  final double size;
  final CustomPainter painter;

  const _FigmaPainterIcon({required this.size, required this.painter});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter),
    );
  }
}

class _FigmaCloseIcon extends _FigmaPainterIcon {
  _FigmaCloseIcon({required super.size, required Color color})
    : super(painter: _ClosePainter(color));
}

class _FigmaHeartIcon extends _FigmaPainterIcon {
  _FigmaHeartIcon({
    required super.size,
    required Color color,
    required bool filled,
  }) : super(painter: _HeartPainter(color, filled));
}

class _FigmaFlameIcon extends _FigmaPainterIcon {
  _FigmaFlameIcon({required super.size, required Color color})
    : super(painter: _FlamePainter(color));
}

class _FigmaVerifiedIcon extends StatelessWidget {
  final double size;

  const _FigmaVerifiedIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF2CE56D),
        shape: BoxShape.circle,
      ),
      child: _FigmaPainterIcon(
        size: size * 0.58,
        painter: const _CheckPainter(Colors.white),
      ),
    );
  }
}

class _FigmaLocationIcon extends _FigmaPainterIcon {
  _FigmaLocationIcon({required super.size, required Color color})
    : super(painter: _LocationPainter(color));
}

class _FigmaBriefcaseIcon extends _FigmaPainterIcon {
  _FigmaBriefcaseIcon({required super.size, required Color color})
    : super(painter: _BriefcasePainter(color));
}

class _FigmaChevronDownIcon extends _FigmaPainterIcon {
  _FigmaChevronDownIcon({required super.size, required Color color})
    : super(painter: _ChevronDownPainter(color));
}

class _FigmaBellIcon extends _FigmaPainterIcon {
  _FigmaBellIcon({required super.size, required Color color})
    : super(painter: _BellPainter(color));
}

class _FigmaMiniChipIcon extends _FigmaPainterIcon {
  _FigmaMiniChipIcon({required super.size, required Color color})
    : super(painter: _SparkPainter(color));
}

class _FigmaStarIcon extends _FigmaPainterIcon {
  _FigmaStarIcon({required super.size, required Color color})
    : super(painter: _StarPainter(color));
}

class _ClosePainter extends CustomPainter {
  final Color color;

  const _ClosePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ClosePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _HeartPainter extends CustomPainter {
  final Color color;
  final bool filled;

  const _HeartPainter(this.color, this.filled);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.86)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.58,
        size.width * 0.05,
        size.height * 0.28,
        size.width * 0.28,
        size.height * 0.18,
      )
      ..cubicTo(
        size.width * 0.40,
        size.height * 0.13,
        size.width * 0.50,
        size.height * 0.24,
        size.width * 0.50,
        size.height * 0.24,
      )
      ..cubicTo(
        size.width * 0.50,
        size.height * 0.24,
        size.width * 0.60,
        size.height * 0.13,
        size.width * 0.72,
        size.height * 0.18,
      )
      ..cubicTo(
        size.width * 0.95,
        size.height * 0.28,
        size.width * 0.88,
        size.height * 0.58,
        size.width * 0.50,
        size.height * 0.86,
      )
      ..close();
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartPainter oldDelegate) =>
      color != oldDelegate.color || filled != oldDelegate.filled;
}

class _FlamePainter extends CustomPainter {
  final Color color;

  const _FlamePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.52, size.height * 0.06)
      ..cubicTo(
        size.width * 0.54,
        size.height * 0.28,
        size.width * 0.28,
        size.height * 0.34,
        size.width * 0.32,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.48,
        size.width * 0.10,
        size.height * 0.76,
        size.width * 0.38,
        size.height * 0.92,
      )
      ..cubicTo(
        size.width * 0.70,
        size.height * 1.05,
        size.width * 0.94,
        size.height * 0.78,
        size.width * 0.78,
        size.height * 0.54,
      )
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.40,
        size.width * 0.58,
        size.height * 0.28,
        size.width * 0.52,
        size.height * 0.06,
      );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _CheckPainter extends CustomPainter {
  final Color color;

  const _CheckPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.82, size.height * 0.28);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _LocationPainter extends CustomPainter {
  final Color color;

  const _LocationPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.38),
      size.width * 0.13,
      paint,
    );
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.95)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.60,
        size.width * 0.22,
        size.height * 0.12,
        size.width * 0.50,
        size.height * 0.10,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.12,
        size.width * 0.80,
        size.height * 0.60,
        size.width * 0.50,
        size.height * 0.95,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LocationPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _BriefcasePainter extends CustomPainter {
  final Color color;

  const _BriefcasePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.32,
        size.width * 0.76,
        size.height * 0.50,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(body, paint);
    canvas.drawLine(
      Offset(size.width * 0.36, size.height * 0.32),
      Offset(size.width * 0.36, size.height * 0.22),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.64, size.height * 0.32),
      Offset(size.width * 0.64, size.height * 0.22),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.36, size.height * 0.22),
      Offset(size.width * 0.64, size.height * 0.22),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BriefcasePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _ChevronDownPainter extends CustomPainter {
  final Color color;

  const _ChevronDownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.36)
      ..lineTo(size.width * 0.50, size.height * 0.68)
      ..lineTo(size.width * 0.82, size.height * 0.36);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronDownPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _BellPainter extends CustomPainter {
  final Color color;

  const _BellPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.26, size.height * 0.72)
      ..lineTo(size.width * 0.74, size.height * 0.72)
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.58,
        size.width * 0.68,
        size.height * 0.44,
        size.width * 0.67,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.15,
        size.width * 0.36,
        size.height * 0.15,
        size.width * 0.33,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.44,
        size.width * 0.34,
        size.height * 0.58,
        size.width * 0.26,
        size.height * 0.72,
      );
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.08),
      Offset(size.width * 0.50, size.height * 0.16),
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.78),
        width: size.width * 0.18,
        height: size.height * 0.16,
      ),
      0,
      3.14,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BellPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _SparkPainter extends CustomPainter {
  final Color color;

  const _SparkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.12),
      Offset(size.width * 0.50, size.height * 0.88),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.50),
      Offset(size.width * 0.88, size.height * 0.50),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _StarPainter extends CustomPainter {
  final Color color;

  const _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.46;
    final innerRadius = size.width * 0.20;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = -1.5708 + i * 0.6283185;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      color != oldDelegate.color;
}

// Retained as a Figma reference while the live People flow uses real profiles.
// ignore: unused_element
class _PeopleDetailPage extends StatelessWidget {
  const _PeopleDetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F8),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAAE2B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: _FigmaChevronDownIcon(
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        _FigmaBellIcon(
                          size: 24,
                          color: const Color(0xFF00473E),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _PeopleHeroCard(),
                    const SizedBox(height: 16),
                    const _InfoPanel(
                      title: 'About Me',
                      chips: ['No', 'No', 'Woman', 'Hindu'],
                    ),
                    const SizedBox(height: 12),
                    const _InfoPanel(
                      title: "I'm Looking For",
                      chips: ['A Long -Term Relationship'],
                    ),
                    const SizedBox(height: 12),
                    const _InfoPanel(
                      title: 'My Interests',
                      chips: ['Foodie', 'Camping', 'Exploring New Cities'],
                    ),
                    const SizedBox(height: 12),
                    const _DetailImage(
                      path: 'assets/images/people/eleonora_detail_1.png',
                    ),
                    const SizedBox(height: 12),
                    const _InfoPanel(
                      title: 'Languages',
                      chips: ['English', 'Hindi'],
                    ),
                    const SizedBox(height: 12),
                    const _DetailImage(
                      path: 'assets/images/people/eleonora_detail_2.png',
                    ),
                    const SizedBox(height: 12),
                    const _PeopleDetailFooter(),
                    const SizedBox(height: 116),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikesPage extends StatefulWidget {
  const _LikesPage();

  @override
  State<_LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<_LikesPage> {
  final List<LinkxReceivedLike> _likes = [];
  StreamSubscription<void>? _matchSubscription;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  String? _actingUserId;

  @override
  void initState() {
    super.initState();
    _loadLikes(refresh: true);
    LinkxChatService.instance.connect().catchError((_) {});
    _matchSubscription = LinkxChatService.instance.matchChanges.listen((_) {
      if (mounted) _loadLikes(refresh: true);
    });
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLikes({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await LinkxApiClient().fetchReceivedLikes(
        page: refresh ? 1 : _page + 1,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _likes.clear();
        _likes.addAll(result.likes);
        _page = result.page;
        _total = result.total;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _likeBack(LinkxReceivedLike item) async {
    if (_actingUserId != null) return;
    setState(() => _actingUserId = item.user.id);
    try {
      final result = await LinkxApiClient().likeUser(item.user.id);
      if (!mounted) return;
      if (!result.matched) {
        _showProfileAction(
          context,
          'The like was saved. Contact unlocks after a mutual match.',
        );
        await _loadLikes(refresh: true);
        return;
      }
      final index = _likes.indexWhere((like) => like.id == item.id);
      if (index >= 0) {
        setState(() => _likes[index] = item.copyWith(matched: true));
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("It's a match!"),
          content: Text(
            'You and ${item.user.name} liked each other. Chat, voice, and video are now unlocked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Great'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showProfileAction(context, error.toString());
    } finally {
      if (mounted) setState(() => _actingUserId = null);
    }
  }

  Future<void> _startCall(LinkxReceivedLike item, {required bool video}) async {
    if (!item.matched) {
      _showProfileAction(
        context,
        'Like ${item.user.name} back to unlock ${video ? 'video calling' : 'voice calling'}.',
      );
      return;
    }
    final result = await LinkxCallService.instance.startCall(
      targetUserId: item.user.id,
      targetUserName: item.user.name,
      isVideoCall: video,
    );
    if (!mounted || result.success) return;
    _showProfileAction(context, result.message ?? 'Unable to start call.');
  }

  void _openChat(LinkxReceivedLike item) {
    if (!item.matched) {
      _showProfileAction(
        context,
        'Like ${item.user.name} back to unlock chat.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChatDetailPage(
          chat: _ChatData(
            item.user.imageUrl,
            item.user.name,
            'You matched. Say hello!',
            'now',
            userId: item.user.id,
          ),
        ),
      ),
    );
  }

  void _openProfile(LinkxReceivedLike item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ExploreProfileDetailPage(
          profile: _ProfileData.fromExploreUser(item.user),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: const Color(0xFFFAAE2B),
        onRefresh: () => _loadLikes(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Likes',
                            style: TextStyle(
                              color: Color(0xFF171717),
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'People who already noticed you',
                            style: TextStyle(
                              color: Color(0xFF817C79),
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8EF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_total',
                        style: const TextStyle(
                          color: Color(0xFFFF3F7A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFAAE2B)),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ExploreMessageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Unable to load likes',
                  message: _error!,
                  buttonText: 'Retry',
                  onTap: () => _loadLikes(refresh: true),
                ),
              )
            else if (_likes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ChatEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No likes yet',
                  message:
                      'When someone likes your profile, they will appear here.',
                  onRefresh: () => _loadLikes(refresh: true),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _likes[index];
                    return _LikeProfileCard(
                      item: item,
                      busy: _actingUserId == item.user.id,
                      onProfile: () => _openProfile(item),
                      onLikeBack: () => _likeBack(item),
                      onCall: () => _startCall(item, video: false),
                      onVideo: () => _startCall(item, video: true),
                      onChat: () => _openChat(item),
                    );
                  }, childCount: _likes.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.59,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  child: Center(
                    child: _hasMore
                        ? OutlinedButton(
                            onPressed: _loadingMore
                                ? null
                                : () => _loadLikes(refresh: false),
                            child: Text(
                              _loadingMore ? 'Loading...' : 'Load more',
                            ),
                          )
                        : const Text(
                            'You are all caught up',
                            style: TextStyle(color: Color(0xFF8A8581)),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LikeProfileCard extends StatelessWidget {
  final LinkxReceivedLike item;
  final bool busy;
  final VoidCallback onProfile;
  final VoidCallback onLikeBack;
  final VoidCallback onCall;
  final VoidCallback onVideo;
  final VoidCallback onChat;

  const _LikeProfileCard({
    required this.item,
    required this.busy,
    required this.onProfile,
    required this.onLikeBack,
    required this.onCall,
    required this.onVideo,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final user = item.user;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onProfile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  user.imageUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFFFE7D0),
                          child: Icon(
                            Icons.person_rounded,
                            size: 64,
                            color: Color(0xFFFAAE2B),
                          ),
                        )
                      : Image.network(
                          user.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFFFE7D0),
                            child: Icon(
                              Icons.person_rounded,
                              size: 64,
                              color: Color(0xFFFAAE2B),
                            ),
                          ),
                        ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: item.matched
                            ? const Color(0xFF20D56B)
                            : const Color(0xFFFF3F7A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        item.matched ? 'MATCHED' : 'LIKED YOU',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.age == null ? user.name : '${user.name}, ${user.age}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF171717),
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF817C79),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!item.matched)
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: busy ? null : onLikeBack,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3F7A),
                          padding: EdgeInsets.zero,
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.favorite_rounded, size: 16),
                        label: Text(busy ? 'Matching...' : 'Like back'),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LikeContactButton(
                          icon: Icons.call_rounded,
                          color: const Color(0xFF00473E),
                          onTap: onCall,
                        ),
                        _LikeContactButton(
                          icon: Icons.videocam_rounded,
                          color: const Color(0xFFFAAE2B),
                          onTap: onVideo,
                        ),
                        _LikeContactButton(
                          icon: Icons.chat_bubble_rounded,
                          color: const Color(0xFFFF3F7A),
                          onTap: onChat,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeContactButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LikeContactButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _ChatListPage extends StatefulWidget {
  const _ChatListPage();

  @override
  State<_ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<_ChatListPage> {
  late Future<List<LinkxConversation>> _conversationsFuture;
  StreamSubscription<LinkxChatMessage>? _messageSubscription;
  StreamSubscription<void>? _matchSubscription;
  StreamSubscription<LinkxReadReceipt>? _readReceiptSubscription;
  StreamSubscription<LinkxPresenceEvent>? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _loadConversations();
    _messageSubscription = LinkxChatService.instance.messages.listen((_) {
      if (mounted) {
        final nextConversations = _loadConversations();
        setState(() {
          _conversationsFuture = nextConversations;
        });
      }
    });
    _matchSubscription = LinkxChatService.instance.matchChanges.listen((_) {
      if (mounted) {
        final nextConversations = _loadConversations();
        setState(() {
          _conversationsFuture = nextConversations;
        });
      }
    });
    _readReceiptSubscription = LinkxChatService.instance.readReceipts.listen(
      (_) => _reloadFromEvent(),
    );
    _presenceSubscription = LinkxChatService.instance.presenceEvents.listen((
      _,
    ) {
      if (mounted) setState(() {});
    });
  }

  void _reloadFromEvent() {
    if (!mounted) return;
    final nextConversations = _loadConversations();
    setState(() {
      _conversationsFuture = nextConversations;
    });
  }

  Future<List<LinkxConversation>> _loadConversations() async {
    await LinkxChatService.instance.connect();
    return LinkxChatService.instance.fetchConversations();
  }

  Future<void> _refresh() async {
    final nextConversations = _loadConversations();
    setState(() {
      _conversationsFuture = nextConversations;
    });
    await _conversationsFuture;
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _matchSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BossyHeader(notificationSize: 24),
            const SizedBox(height: 24),
            const Text(
              'Chat',
              style: TextStyle(
                color: Color(0xFF1E1E1E),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<LinkxConversation>>(
                future: _conversationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFAAE2B),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ChatEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load chats',
                      message: snapshot.error.toString(),
                      onRefresh: _refresh,
                    );
                  }

                  final conversations =
                      snapshot.data ?? const <LinkxConversation>[];
                  if (conversations.isEmpty) {
                    return _ChatEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No conversations yet',
                      message: 'Open a real profile and tap Chat to say hello.',
                      onRefresh: _refresh,
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFFFAAE2B),
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chat = _ChatData.fromConversation(
                          conversations[index],
                        );
                        return _ChatTile(
                          chat: chat,
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => _ChatDetailPage(chat: chat),
                                  ),
                                )
                                .then((_) => _refresh());
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRefresh;

  const _ChatEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFFAAE2B),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 90),
          Icon(icon, color: const Color(0xFFA98CAA), size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF71717B),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final _ChatData chat;
  final VoidCallback onTap;

  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: chat.image.trim().isEmpty
                        ? null
                        : _linkxImageProvider(chat.image),
                    child: chat.image.trim().isEmpty
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                  if (chat.isOnline)
                    Positioned(
                      right: -1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.name,
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF71717B),
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    chat.time,
                    style: const TextStyle(
                      color: Color(0xFFA98CAA),
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (chat.unreadCount > 0) ...[
                    const SizedBox(height: 7),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAAE2B),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatDetailPage extends StatefulWidget {
  final _ChatData chat;

  const _ChatDetailPage({required this.chat});

  @override
  State<_ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<_ChatDetailPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<LinkxChatMessage> _messages = [];
  StreamSubscription<LinkxChatMessage>? _messageSubscription;
  StreamSubscription<LinkxReadReceipt>? _readReceiptSubscription;
  StreamSubscription<LinkxTypingEvent>? _typingSubscription;
  StreamSubscription<LinkxPresenceEvent>? _presenceSubscription;
  Timer? _typingTimer;
  Timer? _remoteTypingTimer;
  String _currentUserId = '';
  String? _nextCursor;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = false;
  bool _sending = false;
  bool _isOnline = false;
  bool _isTyping = false;
  bool _typingSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messageSubscription = LinkxChatService.instance.messages.listen(
      _handleIncomingMessage,
    );
    _readReceiptSubscription = LinkxChatService.instance.readReceipts.listen(
      _handleReadReceipt,
    );
    _typingSubscription = LinkxChatService.instance.typingEvents.listen(
      _handleTyping,
    );
    _presenceSubscription = LinkxChatService.instance.presenceEvents.listen(
      _handlePresence,
    );
    _scrollController.addListener(_handleScroll);
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.chat.userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This profile is not connected to a real user.';
      });
      return;
    }

    try {
      final results = await Future.wait([
        LinkxApiClient().fetchCurrentUser(),
        LinkxChatService.instance.fetchMessagePage(widget.chat.userId),
        LinkxChatService.instance.connect(),
      ]);
      if (!mounted) return;
      final currentUser = results[0] as LinkxCurrentUser;
      final page = results[1] as LinkxMessagePage;
      setState(() {
        _currentUserId = currentUser.id;
        _messages
          ..clear()
          ..addAll(page.messages);
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
        _isOnline = LinkxChatService.instance.isOnline(widget.chat.userId);
        _loading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _handleIncomingMessage(LinkxChatMessage message) {
    final belongsToChat =
        message.senderId == widget.chat.userId ||
        message.recipientId == widget.chat.userId;
    if (!mounted || !belongsToChat || _containsMessage(message.id)) return;
    setState(() {
      _messages.add(message);
      if (message.senderId == widget.chat.userId) _isTyping = false;
    });
    if (message.recipientId == _currentUserId) {
      LinkxChatService.instance.markRead(widget.chat.userId);
    }
    _scrollToBottom();
  }

  void _handleReadReceipt(LinkxReadReceipt receipt) {
    if (!mounted || receipt.readerId != widget.chat.userId) return;
    var changed = false;
    final readAt = receipt.readAt ?? DateTime.now();
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      final wasSentBeforeReceipt =
          message.createdAt == null || !message.createdAt!.isAfter(readAt);
      if (message.senderId == _currentUserId &&
          message.readAt == null &&
          wasSentBeforeReceipt) {
        _messages[index] = message.copyWith(readAt: readAt);
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  void _handleTyping(LinkxTypingEvent event) {
    if (!mounted || event.userId != widget.chat.userId) return;
    _remoteTypingTimer?.cancel();
    setState(() => _isTyping = event.isTyping);
    if (event.isTyping) {
      _remoteTypingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  void _handlePresence(LinkxPresenceEvent event) {
    if (!mounted) return;
    final isOnline = LinkxChatService.instance.isOnline(widget.chat.userId);
    if (isOnline != _isOnline) setState(() => _isOnline = isOnline);
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 80) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMore || _nextCursor == null) return;
    setState(() => _loadingOlder = true);
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      final page = await LinkxChatService.instance.fetchMessagePage(
        widget.chat.userId,
        before: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _messages.insertAll(
          0,
          page.messages.where((message) => !_containsMessage(message.id)),
        );
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        _scrollController.jumpTo(
          (_scrollController.position.pixels + addedExtent).clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  bool _containsMessage(String id) {
    return id.isNotEmpty && _messages.any((message) => message.id == id);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || widget.chat.userId.isEmpty) return;
    setState(() => _sending = true);
    try {
      final message = await LinkxChatService.instance.sendMessage(
        recipientId: widget.chat.userId,
        text: text,
      );
      if (!mounted) return;
      _controller.clear();
      _stopTyping();
      if (!_containsMessage(message.id)) {
        setState(() => _messages.add(message));
      }
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onComposerChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText && !_typingSent) {
      _typingSent = true;
      LinkxChatService.instance.setTyping(
        recipientId: widget.chat.userId,
        isTyping: true,
      );
    }
    _typingTimer?.cancel();
    if (!hasText) {
      _stopTyping();
      return;
    }
    _typingTimer = Timer(const Duration(milliseconds: 900), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (!_typingSent) return;
    _typingSent = false;
    LinkxChatService.instance.setTyping(
      recipientId: widget.chat.userId,
      isTyping: false,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _typingSubscription?.cancel();
    _presenceSubscription?.cancel();
    _typingTimer?.cancel();
    _remoteTypingTimer?.cancel();
    if (_typingSent) {
      LinkxChatService.instance.setTyping(
        recipientId: widget.chat.userId,
        isTyping: false,
      );
    }
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: widget.chat.image.trim().isEmpty
                        ? null
                        : _linkxImageProvider(widget.chat.image),
                    child: widget.chat.image.trim().isEmpty
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chat.name,
                          style: const TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _isTyping
                              ? 'typing...'
                              : _isOnline
                              ? 'online'
                              : 'offline',
                          style: TextStyle(
                            color: _isTyping || _isOnline
                                ? const Color(0xFF22A06B)
                                : const Color(0xFF8A8A93),
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz_rounded),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFAAE2B),
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF71717B)),
                        ),
                      ),
                    )
                  : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Say hi and start the conversation.',
                        style: TextStyle(
                          color: Color(0xFF71717B),
                          fontFamily: 'Bricolage Grotesque',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      itemCount: _messages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_hasMore && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: _loadingOlder
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFAAE2B),
                                      ),
                                    )
                                  : const Text(
                                      'Scroll up for older messages',
                                      style: TextStyle(
                                        color: Color(0xFF8A8A93),
                                        fontSize: 11,
                                      ),
                                    ),
                            ),
                          );
                        }
                        final message = _messages[index - (_hasMore ? 1 : 0)];
                        final mine = message.senderId == _currentUserId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFFFAAE2B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    color: mine ? Colors.white : Colors.black,
                                    fontFamily: 'Bricolage Grotesque',
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                                if (mine) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    message.readAt == null ? 'Sent' : 'Read',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontFamily: 'Inter',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_loading && _error == null,
                      onChanged: _onComposerChanged,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    backgroundColor: const Color(0xFFFAAE2B),
                    onPressed: _sending ? null : _sendMessage,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfilePage extends StatefulWidget {
  const _UserProfilePage();

  @override
  State<_UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<_UserProfilePage> {
  String _selectedPlan = 'Premium';
  late Future<LinkxCurrentUser> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = LinkxApiClient().fetchCurrentUser();
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  Future<void> _logout() async {
    await LinkxCallService.instance.uninitialize();
    LinkxChatService.instance.disconnect();
    await LinkxApiClient.clearAuthToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openPage(Widget page) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true && mounted) {
      setState(() {
        _userFuture = LinkxApiClient().fetchCurrentUser();
      });
    }
  }

  void _openSetting(String label, LinkxCurrentUser user) {
    switch (label) {
      case 'Privacy':
        _openPage(_AccountSettingsPage(user: user, privacy: true));
      case 'Notifications':
        _openPage(_AccountSettingsPage(user: user, privacy: false));
      case 'Terms of service':
        _openPage(const _LegalPage(type: _LegalType.terms));
      case 'Privacy policy':
        _openPage(const _LegalPage(type: _LegalType.privacy));
      case 'Community guidelines':
        _openPage(const _LegalPage(type: _LegalType.community));
      case 'Help & support':
        _openPage(const _SupportPage());
      case 'Delete account':
        _openPage(const _DeleteAccountPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<LinkxCurrentUser>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFAAE2B)),
            );
          }
          if (snapshot.hasError) {
            return _ChatEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load profile',
              message: snapshot.error.toString(),
              onRefresh: () async {
                setState(() {
                  _userFuture = LinkxApiClient().fetchCurrentUser();
                });
                await _userFuture;
              },
            );
          }
          final user = snapshot.data!;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserTopBar(name: user.name, onAction: _showAction),
                const SizedBox(height: 34),
                _UserSummary(user: user),
                const SizedBox(height: 17),
                _UserActionButtons(
                  onEdit: () => _openPage(_EditProfilePage(user: user)),
                  onShare: () => _showAction('Profile sharing coming soon'),
                ),
                const SizedBox(height: 17),
                _UserPlans(
                  selectedPlan: _selectedPlan,
                  onSelected: (plan) async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => _BillingPage(initialPlanName: plan),
                      ),
                    );
                    if (changed == true && mounted) {
                      setState(() => _selectedPlan = plan);
                    }
                  },
                ),
                const SizedBox(height: 17),
                _BalanceCard(onTap: () => _showAction('Wallet opened')),
                const SizedBox(height: 8),
                _GiftVoucherCard(
                  onTap: () => _showAction('Gift voucher selected'),
                ),
                const SizedBox(height: 16),
                _HostCard(onTap: () => _openPage(_BecomeHostPage(user: user))),
                const SizedBox(height: 16),
                _SettingsCard(onTap: (label) => _openSetting(label, user)),
                const SizedBox(height: 16),
                _LogoutCard(onTap: _logout),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccountPageShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _AccountPageShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F8),
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Bricolage Grotesque',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

class _BecomeHostPage extends StatefulWidget {
  final LinkxCurrentUser user;

  const _BecomeHostPage({required this.user});

  @override
  State<_BecomeHostPage> createState() => _BecomeHostPageState();
}

class _BecomeHostPageState extends State<_BecomeHostPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _topics;
  late final TextEditingController _languages;
  late final TextEditingController _experience;
  late Future<LinkxHostApplicationStatus> _statusFuture;
  XFile? _media;
  String _mediaKind = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _bio = TextEditingController(text: widget.user.bio);
    _topics = TextEditingController(
      text: widget.user.interests.take(4).join(', '),
    );
    _languages = TextEditingController(text: 'English');
    _experience = TextEditingController();
    _statusFuture = LinkxApiClient().fetchHostApplicationStatus();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _topics.dispose();
    _languages.dispose();
    _experience.dispose();
    super.dispose();
  }

  Future<void> _pickSelfie() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (file != null && mounted) {
      setState(() {
        _media = file;
        _mediaKind = 'Selfie photo';
      });
    }
  }

  Future<void> _pickIntroVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (file != null && mounted) {
      setState(() {
        _media = file;
        _mediaKind = 'Intro video';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await LinkxApiClient().submitHostApplication(
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        topics: _parseList(_topics.text),
        languages: _parseList(_languages.text),
        experience: _experience.text.trim(),
        media: _media,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Host application sent for admin approval'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      setState(() {
        _statusFuture = LinkxApiClient().fetchHostApplicationStatus();
        _media = null;
        _mediaKind = '';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<String> _parseList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Become a host',
      child: FutureBuilder<LinkxHostApplicationStatus>(
        future: _statusFuture,
        builder: (context, snapshot) {
          final status = snapshot.data;
          final pending = status?.status == 'pending';
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HostHeroCard(status: status),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HostFormField(
                        controller: _name,
                        label: 'Host name',
                        hint: 'Example: Rahul Talks',
                        validator: (value) => value.trim().length < 2
                            ? 'Enter your host name'
                            : null,
                      ),
                      _HostFormField(
                        controller: _bio,
                        label: 'Bio',
                        hint:
                            'Tell members what kind of conversations you host.',
                        minLines: 4,
                        maxLines: 6,
                        validator: (value) => value.trim().length < 20
                            ? 'Bio must be at least 20 characters'
                            : null,
                      ),
                      _HostFormField(
                        controller: _topics,
                        label: 'Topics',
                        hint: 'Music, cooking, dating, food, travel',
                        validator: (value) => _parseList(value).isEmpty
                            ? 'Add at least one topic'
                            : null,
                      ),
                      _HostFormField(
                        controller: _languages,
                        label: 'Languages',
                        hint: 'English, Tamil, Hindi',
                        validator: (value) => _parseList(value).isEmpty
                            ? 'Add at least one language'
                            : null,
                      ),
                      _HostFormField(
                        controller: _experience,
                        label: 'Experience',
                        hint:
                            'Share past hosting, speaking, teaching, or community experience.',
                        minLines: 4,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sample intro or selfie',
                        style: TextStyle(
                          color: Color(0xFF1F1D1C),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _HostMediaPickerCard(
                        media: _media,
                        mediaKind: _mediaKind,
                        onPickSelfie: _pickSelfie,
                        onPickVideo: _pickIntroVideo,
                        onClear: () => setState(() {
                          _media = null;
                          _mediaKind = '';
                        }),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: pending || _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFAAE2B),
                            disabledBackgroundColor: const Color(0xFFE7E2E4),
                            foregroundColor: const Color(0xFF00473E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00473E),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  pending
                                      ? 'Waiting for admin approval'
                                      : 'Send application',
                                  style: const TextStyle(
                                    fontFamily: 'Bricolage Grotesque',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HostHeroCard extends StatelessWidget {
  final LinkxHostApplicationStatus? status;

  const _HostHeroCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final state = status?.status ?? 'not_applied';
    final title = switch (state) {
      'approved' => 'You are an approved Linkx host',
      'pending' => 'Application under review',
      'rejected' => 'Application needs changes',
      _ => 'Apply to become a Linkx host',
    };
    final message = switch (state) {
      'approved' => 'Your profile can now appear in Explore as approved staff.',
      'pending' => 'Admin will review your profile, topics, and sample media.',
      'rejected' =>
        status?.application?.adminNote.isNotEmpty == true
            ? status!.application!.adminNote
            : 'Update your details and apply again.',
      _ =>
        'Tell us what you host. Add a selfie or short intro video if you want a stronger application.',
    };
    final icon = switch (state) {
      'approved' => Icons.verified_rounded,
      'pending' => Icons.hourglass_top_rounded,
      'rejected' => Icons.error_outline_rounded,
      _ => Icons.mic_external_on_rounded,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF07483F), Color(0xFF0B6B5D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00473E).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: const Color(0xFFFAAE2B), size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFDCEFE9),
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HostFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int minLines;
  final int maxLines;
  final String? Function(String value)? validator;

  const _HostFormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1F1D1C),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            validator: (value) => validator?.call(value ?? ''),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE7E2E4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE7E2E4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFFFAAE2B),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostMediaPickerCard extends StatelessWidget {
  final XFile? media;
  final String mediaKind;
  final VoidCallback onPickSelfie;
  final VoidCallback onPickVideo;
  final VoidCallback onClear;

  const _HostMediaPickerCard({
    required this.media,
    required this.mediaKind,
    required this.onPickSelfie,
    required this.onPickVideo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E2E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (media == null) ...[
            const Text(
              'Optional, but recommended. A short intro helps admin approve faster.',
              style: TextStyle(
                color: Color(0xFF777370),
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickSelfie,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Selfie'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickVideo,
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Video'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4DE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    mediaKind.contains('video')
                        ? Icons.play_circle_outline_rounded
                        : Icons.photo_camera_outlined,
                    color: const Color(0xFFFAAE2B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mediaKind,
                        style: const TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        media!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF777370),
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EditProfilePage extends StatefulWidget {
  final LinkxCurrentUser user;

  const _EditProfilePage({required this.user});

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _height;
  late final TextEditingController _education;
  late final TextEditingController _lookingFor;
  late final TextEditingController _interests;
  late final TextEditingController _children;
  late final TextEditingController _smoking;
  late String _identity;
  DateTime? _birthDate;
  List<XFile> _photos = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _bio = TextEditingController(text: widget.user.bio);
    _height = TextEditingController(
      text: widget.user.heightCm?.toString() ?? '',
    );
    _education = TextEditingController(text: widget.user.educationLevel);
    _lookingFor = TextEditingController(text: widget.user.lookingFor);
    _interests = TextEditingController(text: widget.user.interests.join(', '));
    _children = TextEditingController(text: widget.user.children);
    _smoking = TextEditingController(text: widget.user.smoking);
    _identity = widget.user.identity.isEmpty ? 'Other' : widget.user.identity;
    _birthDate = widget.user.birthDate;
  }

  Future<void> _pickPhotos() async {
    final photos = await _picker.pickMultiImage(imageQuality: 82, limit: 6);
    if (photos.isNotEmpty && mounted) setState(() => _photos = photos);
  }

  Future<void> _pickBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1995),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 18 * 365)),
    );
    if (selected != null && mounted) setState(() => _birthDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      if (_photos.isNotEmpty) {
        await LinkxApiClient().uploadPhotos(_photos);
      }
      await LinkxApiClient().updateProfile({
        'firstName': _name.text.trim(),
        'bio': _bio.text.trim(),
        'identity': _identity,
        if (_birthDate != null) 'birthDate': _birthDate!.toIso8601String(),
        'heightCm': int.tryParse(_height.text.trim()),
        'educationLevel': _education.text.trim(),
        'lookingFor': _lookingFor.text.trim(),
        'happiness': _interests.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(12)
            .toList(),
        'children': _children.text.trim(),
        'smoking': _smoking.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _height.dispose();
    _education.dispose();
    _lookingFor.dispose();
    _interests.dispose();
    _children.dispose();
    _smoking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Edit profile',
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            OutlinedButton.icon(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _photos.isEmpty
                    ? 'Replace profile photos'
                    : '${_photos.length} photos selected',
              ),
            ),
            const SizedBox(height: 16),
            _AccountTextField(
              controller: _name,
              label: 'Name',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Name is required'
                  : null,
            ),
            _AccountTextField(
              controller: _bio,
              label: 'Bio',
              maxLines: 4,
              maxLength: 500,
            ),
            DropdownButtonFormField<String>(
              initialValue: _identity,
              decoration: _accountInputDecoration('Identity'),
              items: const [
                DropdownMenuItem(value: 'Him', child: Text('Him')),
                DropdownMenuItem(value: 'Her', child: Text('Her')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) =>
                  setState(() => _identity = value ?? 'Other'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Text('Birth date'),
              subtitle: Text(
                _birthDate == null
                    ? 'Not set'
                    : DateFormat('MMMM d, yyyy').format(_birthDate!),
              ),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 12),
            _AccountTextField(
              controller: _height,
              label: 'Height (cm)',
              keyboardType: TextInputType.number,
            ),
            _AccountTextField(controller: _education, label: 'Education'),
            _AccountTextField(
              controller: _lookingFor,
              label: 'What are you looking for?',
            ),
            _AccountTextField(
              controller: _interests,
              label: 'Interests, separated by commas',
            ),
            _AccountTextField(controller: _children, label: 'Children'),
            _AccountTextField(controller: _smoking, label: 'Smoking'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFAAE2B),
                foregroundColor: const Color(0xFF00473E),
                minimumSize: const Size.fromHeight(50),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AccountTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator,
        decoration: _accountInputDecoration(label),
      ),
    );
  }
}

InputDecoration _accountInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

class _AccountSettingsPage extends StatefulWidget {
  final LinkxCurrentUser user;
  final bool privacy;

  const _AccountSettingsPage({required this.user, required this.privacy});

  @override
  State<_AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<_AccountSettingsPage> {
  late Map<String, bool> _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = Map.of(
      widget.privacy
          ? widget.user.privacySettings
          : widget.user.notificationSettings,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await LinkxApiClient().updateAccountSettings(
        privacySettings: widget.privacy ? _settings : null,
        notificationSettings: widget.privacy ? null : _settings,
      );
      if (widget.privacy) {
        LinkxChatService.instance.disconnect();
        await LinkxChatService.instance.connect();
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.privacy
        ? const {
            'discoverable': 'Show me in discovery',
            'showOnlineStatus': 'Show online status',
            'showDistance': 'Show my distance',
            'showAge': 'Show my age',
          }
        : const {
            'newMatches': 'New matches',
            'messages': 'Messages',
            'likes': 'Likes',
            'calls': 'Calls',
          };
    return _AccountPageShell(
      title: widget.privacy ? 'Privacy' : 'Notifications',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final entry in labels.entries)
                  SwitchListTile(
                    title: Text(entry.value),
                    value: _settings[entry.key] ?? true,
                    activeTrackColor: const Color(0xFFFAAE2B),
                    onChanged: (value) =>
                        setState(() => _settings[entry.key] = value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFAAE2B),
              foregroundColor: const Color(0xFF00473E),
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_saving ? 'Saving...' : 'Save settings'),
          ),
        ],
      ),
    );
  }
}

class _BillingPage extends StatefulWidget {
  final String initialPlanName;

  const _BillingPage({required this.initialPlanName});

  @override
  State<_BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<_BillingPage> {
  late Future<List<Object>> _future;
  String _selectedPlanId = 'premium';
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.initialPlanName.toLowerCase();
    _future = Future.wait([
      LinkxApiClient().fetchBillingPlans(),
      LinkxApiClient().fetchBillingStatus(),
    ]);
  }

  Future<void> _purchase() async {
    if (_selectedPlanId == 'free' || _purchasing) return;
    setState(() => _purchasing = true);
    try {
      await LinkxApiClient().purchasePlan(_selectedPlanId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan activated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showProfileAction(context, error.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Membership',
      child: FutureBuilder<List<Object>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFAAE2B)),
            );
          }
          if (snapshot.hasError) {
            return _ChatEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load plans',
              message: snapshot.error.toString(),
              onRefresh: () async {
                final next = Future.wait([
                  LinkxApiClient().fetchBillingPlans(),
                  LinkxApiClient().fetchBillingStatus(),
                ]);
                setState(() => _future = next);
                await next;
              },
            );
          }
          final plans = snapshot.data![0] as List<LinkxBillingPlan>;
          final status = snapshot.data![1] as LinkxBillingStatus;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1DB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current plan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status.plan.name.isEmpty ? 'Free' : status.plan.name,
                      style: const TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (status.expiresAt != null)
                      Text(
                        'Renews until ${DateFormat('MMM d, yyyy').format(status.expiresAt!)}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              for (final plan in plans.where((plan) => plan.id != 'free')) ...[
                _BillingPlanTile(
                  plan: plan,
                  selected: _selectedPlanId == plan.id,
                  active: status.plan.id == plan.id,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _purchasing ? null : _purchase,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFAAE2B),
                  foregroundColor: const Color(0xFF00473E),
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: Text(_purchasing ? 'Activating...' : 'Activate plan'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BillingPlanTile extends StatelessWidget {
  final LinkxBillingPlan plan;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  const _BillingPlanTile({
    required this.plan,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFAAE2B)
                  : const Color(0xFFECECEC),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (active)
                    const Chip(
                      label: Text('Active'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              Text(
                _money(plan.priceCents, plan.currency),
                style: const TextStyle(
                  color: Color(0xFF00473E),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final feature in plan.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF22A06B),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(int cents, String currency) {
  final amount = cents / 100;
  final symbol = currency == 'INR' ? '₹' : '$currency ';
  return '$symbol${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}/month';
}

enum _LegalType { terms, privacy, community }

class _LegalPage extends StatelessWidget {
  final _LegalType type;

  const _LegalPage({required this.type});

  @override
  Widget build(BuildContext context) {
    final content = switch (type) {
      _LegalType.terms => (
        'Terms of service',
        'By using Linkx, you agree to provide accurate account information, '
            'use the service lawfully, respect other members, and avoid abusive, '
            'fraudulent, or harmful conduct. You are responsible for activity on '
            'your account. Linkx may restrict accounts that violate these terms.',
      ),
      _LegalType.privacy => (
        'Privacy policy',
        'Linkx stores profile details, preferences, matches, messages, reports, '
            'and support requests to operate the service. Privacy controls let '
            'you limit discovery, age, distance, and online visibility. Deleting '
            'your account removes your profile, uploaded photos, relationships, '
            'and messages from the active service.',
      ),
      _LegalType.community => (
        'Community guidelines',
        'Be respectful, use your real identity, obtain consent, and keep chats '
            'safe. Harassment, hate, threats, sexual exploitation, scams, spam, '
            'impersonation, and underage use are prohibited. Block or report any '
            'member who makes you feel unsafe.',
      ),
    };
    return _AccountPageShell(
      title: content.$1,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Last updated June 6, 2026',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717B)),
          ),
          const SizedBox(height: 18),
          Text(content.$2, style: const TextStyle(fontSize: 15, height: 1.7)),
        ],
      ),
    );
  }
}

class _SupportPage extends StatefulWidget {
  const _SupportPage();

  @override
  State<_SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<_SupportPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  Future<void> _submit() async {
    if (_subject.text.trim().length < 3 || _message.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a subject and more details.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await LinkxApiClient().submitSupportRequest(
        subject: _subject.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request submitted.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Help & support',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tell us what happened. Your request is saved for the support team.',
          ),
          const SizedBox(height: 18),
          _AccountTextField(controller: _subject, label: 'Subject'),
          _AccountTextField(
            controller: _message,
            label: 'How can we help?',
            maxLines: 7,
            maxLength: 2000,
          ),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFAAE2B),
              foregroundColor: const Color(0xFF00473E),
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_sending ? 'Sending...' : 'Submit request'),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountPage extends StatefulWidget {
  const _DeleteAccountPage();

  @override
  State<_DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<_DeleteAccountPage> {
  final _confirmation = TextEditingController();
  bool _deleting = false;

  Future<void> _delete() async {
    if (_confirmation.text.trim() != 'DELETE' || _deleting) return;
    setState(() => _deleting = true);
    try {
      await LinkxCallService.instance.uninitialize();
      LinkxChatService.instance.disconnect();
      await LinkxApiClient().deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
        setState(() => _deleting = false);
      }
    }
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Delete account',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'This permanently deletes your profile, uploaded photos, matches, '
            'likes, blocks, reports, conversations, and messages.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _confirmation,
            onChanged: (_) => setState(() {}),
            decoration: _accountInputDecoration('Type DELETE to confirm'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _confirmation.text.trim() == 'DELETE' && !_deleting
                ? _delete
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_deleting ? 'Deleting...' : 'Delete permanently'),
          ),
        ],
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFECECEC)),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFE53935),
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFE53935),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTopBar extends StatelessWidget {
  final String name;
  final ValueChanged<String> onAction;

  const _UserTopBar({required this.name, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onAction('Menu'),
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF111111)),
        ),
        Expanded(
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF111111),
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 0.98,
            ),
          ),
        ),
        Stack(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => onAction('Notifications'),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF111111),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAAE2B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserSummary extends StatelessWidget {
  final LinkxCurrentUser user;

  const _UserSummary({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFAAE2B).withValues(alpha: 0.95),
                        spreadRadius: 2,
                      ),
                    ],
                    image: user.avatarUrl.isEmpty
                        ? null
                        : DecorationImage(
                            image: _linkxImageProvider(user.avatarUrl),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A56DB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      color: Color(0xFF111318),
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _UserStat(
                        value: user.identity.isEmpty
                            ? 'Not set'
                            : user.identity,
                        label: 'Identity',
                      ),
                      _UserStat(
                        value: user.location.isEmpty
                            ? 'Not set'
                            : user.location,
                        label: 'Location',
                      ),
                      _UserStat(
                        value: '${user.interests.length}',
                        label: 'Interests',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          user.bio.isEmpty
              ? 'Add a bio to help matches get to know you.'
              : user.bio,
          style: TextStyle(
            color: Color(0xFF111318),
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.63,
          ),
        ),
      ],
    );
  }
}

class _UserStat extends StatelessWidget {
  final String value;
  final String label;

  const _UserStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111318),
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A8F9E),
              fontFamily: 'Inter',
              fontSize: 11,
              height: 1.33,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserActionButtons extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onShare;

  const _UserActionButtons({required this.onEdit, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PillButton(
            label: 'Edit profile',
            icon: Icons.manage_accounts_outlined,
            filled: true,
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _PillButton(
            label: 'Share Profile',
            icon: Icons.ios_share_rounded,
            filled: false,
            onTap: onShare,
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: filled
              ? const Color(0xFFFAAE2B)
              : Colors.transparent,
          foregroundColor: filled
              ? const Color(0xFF00473E)
              : const Color(0xFFFAAE2B),
          side: const BorderSide(color: Color(0xFFFAAE2B)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _UserPlans extends StatelessWidget {
  final String selectedPlan;
  final ValueChanged<String> onSelected;

  const _UserPlans({required this.selectedPlan, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Membership Plans',
              style: TextStyle(
                color: Color(0xFF111111),
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.43,
              ),
            ),
            Text(
              'Upgrade',
              style: TextStyle(
                color: Color(0xFF1A56DB),
                decoration: TextDecoration.underline,
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x338A8F9E)),
          ),
          child: Row(
            children: [
              _PlanItem(
                title: 'Premium',
                subtitle: 'More choices',
                icon: Icons.local_fire_department_rounded,
                bg: const Color(0xFFFFF6D8),
                selected: selectedPlan == 'Premium',
                onTap: () => onSelected('Premium'),
              ),
              _PlanDivider(),
              _PlanItem(
                title: 'Plus',
                subtitle: 'Best choice',
                icon: Icons.bolt_rounded,
                bg: const Color(0xFFF8EAFF),
                selected: selectedPlan == 'Plus',
                onTap: () => onSelected('Plus'),
              ),
              _PlanDivider(),
              _PlanItem(
                title: 'Linkx',
                subtitle: 'Full access',
                icon: Icons.workspace_premium_rounded,
                bg: const Color(0xFFEAF4FF),
                selected: selectedPlan == 'Linkx',
                onTap: () => onSelected('Linkx'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 70, color: const Color(0xFFE3E3E3));
  }
}

class _PlanItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  const _PlanItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF8E8) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: const Color(0xFFFAAE2B)),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontFamily: 'Inter',
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BalanceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PromoCard(
      height: 104,
      gradient: const LinearGradient(
        colors: [Color(0xFF52B05C), Color(0xFF2B8876)],
      ),
      icon: Icons.account_balance_wallet_outlined,
      iconColor: Colors.white,
      title: 'Available balance',
      amount: '₹0.00',
      body:
          'Linkx money can be used for all your Selected\nProfiles and events.',
      image: 'assets/images/user/coins.png',
      onTap: onTap,
    );
  }
}

class _GiftVoucherCard extends StatelessWidget {
  final VoidCallback onTap;

  const _GiftVoucherCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PromoCard(
      height: 116,
      color: Colors.white,
      icon: Icons.card_giftcard_rounded,
      iconColor: const Color(0xFF00473E),
      title: 'Share love through e-gift\nVouchers',
      body:
          'Celebrate a special occasion with your loved ones with\ne-gift vouchers',
      link: 'Buy a gift voucher',
      image: 'assets/images/user/gift.png',
      onTap: onTap,
    );
  }
}

class _PromoCard extends StatelessWidget {
  final double height;
  final Color? color;
  final Gradient? gradient;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? amount;
  final String body;
  final String? link;
  final String image;
  final VoidCallback onTap;

  const _PromoCard({
    required this.height,
    this.color,
    this.gradient,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.amount,
    required this.body,
    this.link,
    required this.image,
    required this.onTap,
  });

  bool get _dark => gradient != null;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x338A8F9E)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0x1A475D5B),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(icon, size: 19, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: _dark
                                ? Colors.white
                                : const Color(0xFF212121),
                            fontFamily: amount == null
                                ? 'Bricolage Grotesque'
                                : 'Inter',
                            fontSize: amount == null ? 16 : 11,
                            fontWeight: amount == null
                                ? FontWeight.w700
                                : FontWeight.w400,
                            height: amount == null ? 1.25 : 1.33,
                          ),
                        ),
                        if (amount != null)
                          Text(
                            amount!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.75,
                            ),
                          ),
                        Text(
                          body,
                          style: TextStyle(
                            color: _dark
                                ? Colors.white.withValues(alpha: 0.74)
                                : const Color(0x9E212121),
                            fontFamily: 'Inter',
                            fontSize: 8,
                            height: 1.5,
                          ),
                        ),
                        if (link != null)
                          Text(
                            link!,
                            style: const TextStyle(
                              color: Color(0xFFFAAE2B),
                              decoration: TextDecoration.underline,
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(image, width: 74, height: 74, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final VoidCallback onTap;

  const _HostCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFAAE2B),
                foregroundColor: const Color(0xFF00473E),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              icon: const Icon(Icons.mic_none_rounded, size: 18),
              label: const Text(
                'Become a host',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create, manage, and grow your audience with powerful hosting tools.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0x9E212121),
              fontFamily: 'Inter',
              fontSize: 8,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final ValueChanged<String> onTap;

  const _SettingsCard({required this.onTap});

  static const _items = [
    _SettingData(Icons.lock_outline_rounded, 'Privacy'),
    _SettingData(Icons.notifications_none_rounded, 'Notifications'),
    _SettingData(Icons.description_outlined, 'Terms of service'),
    _SettingData(Icons.policy_outlined, 'Privacy policy'),
    _SettingData(Icons.groups_outlined, 'Community guidelines'),
    _SettingData(Icons.support_agent_rounded, 'Help & support'),
    _SettingData(Icons.delete_outline_rounded, 'Delete account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            _SettingsRow(item: _items[i], onTap: () => onTap(_items[i].label)),
            if (i != _items.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final _SettingData item;
  final VoidCallback onTap;

  const _SettingsRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(item.icon, size: 22, color: const Color(0xFF00473E)),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 2,
                letterSpacing: -0.45,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}

class _SettingData {
  final IconData icon;
  final String label;

  const _SettingData(this.icon, this.label);
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<String> chips;

  const _InfoPanel({required this.title, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final chip in chips) _MiniChip(label: chip)],
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() onSearch;
  final Future<void> Function() onFilter;

  const _SearchAndFilter({
    required this.controller,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0x80000000),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Search profiles...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1F000000), width: 0.5),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 18,
                color: Color(0xFF00473E),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderToggle extends StatelessWidget {
  final String? selectedIdentity;
  final ValueChanged<String?> onChanged;

  const _GenderToggle({
    required this.selectedIdentity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0x0F18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        children: [
          _GenderOption(
            icon: Icons.male_rounded,
            label: 'Male',
            selected: selectedIdentity == 'Him',
            onTap: () => onChanged(selectedIdentity == 'Him' ? null : 'Him'),
          ),
          _GenderOption(
            icon: Icons.female_rounded,
            label: 'Female',
            selected: selectedIdentity == 'Her',
            onTap: () => onChanged(selectedIdentity == 'Her' ? null : 'Her'),
          ),
        ],
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFAAE2B) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0x80000000),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0x80000000),
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? action;

  const _ExploreSectionHeader({
    required this.icon,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFAAE2B), size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: -0.45,
              ),
            ),
          ],
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              color: Color(0xFF00473E),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _ChatData {
  final String userId;
  final String image;
  final String name;
  final String message;
  final String time;
  final int unreadCount;
  final bool isOnline;

  const _ChatData(
    this.image,
    this.name,
    this.message,
    this.time, {
    this.userId = '',
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory _ChatData.fromConversation(LinkxConversation conversation) {
    return _ChatData(
      conversation.userImageUrl,
      conversation.userName,
      conversation.lastMessage,
      _chatTime(conversation.lastMessageAt),
      userId: conversation.userId,
      unreadCount: conversation.unreadCount,
      isOnline: LinkxChatService.instance.isOnline(conversation.userId),
    );
  }
}

String _chatTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.inMinutes < 1) return 'now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return DateFormat('MMM d').format(local);
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FigmaMiniChipIcon(size: 9, color: const Color(0xFF71717B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailImage extends StatelessWidget {
  final String path;

  const _DetailImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 358.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            path,
            width: width,
            height: width * 455 / 358,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _PeopleDetailFooter extends StatelessWidget {
  const _PeopleDetailFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _LocationPanel(),
        const SizedBox(height: 47),
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: Color(0xFFFFD84D),
            shape: BoxShape.circle,
          ),
          child: Center(child: _FigmaStarIcon(size: 34, color: Colors.black)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LargeCircleAction(
              icon: _FigmaCloseIcon(size: 22, color: Colors.white),
            ),
            _LargeCircleAction(
              icon: _FigmaHeartIcon(
                size: 24,
                color: Colors.white,
                filled: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 23),
        const Text(
          'Block',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Bricolage Grotesque',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Report',
          style: TextStyle(
            color: Color(0xFFE80000),
            fontFamily: 'Bricolage Grotesque',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 112,
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x17000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Location',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FigmaLocationIcon(size: 12, color: Colors.black),
              const SizedBox(width: 9),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Madurai',
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '17 Km Away',
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LargeCircleAction extends StatelessWidget {
  final Widget icon;

  const _LargeCircleAction({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Center(child: icon),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String text;

  const _GlassChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Bricolage Grotesque',
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PeopleFact extends StatelessWidget {
  final Widget icon;
  final String text;

  const _PeopleFact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 16, height: 16, child: Center(child: icon)),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Bricolage Grotesque',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _BossyHeader extends StatelessWidget {
  final double notificationSize;

  const _BossyHeader({this.notificationSize = 46});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const _LinkxHeaderLogo(width: 77, height: 16),
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _NotificationInboxPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(notificationSize / 2),
          child: Container(
            width: notificationSize,
            height: notificationSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(notificationSize / 2),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: notificationSize * 0.61,
              color: const Color(0xFF00473E),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationInboxPage extends StatefulWidget {
  const _NotificationInboxPage();

  @override
  State<_NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<_NotificationInboxPage> {
  late Future<LinkxNotificationPage> _future;
  StreamSubscription<LinkxNotification>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = LinkxApiClient().fetchNotifications();
    _subscription = LinkxChatService.instance.notifications.listen((_) {
      if (mounted) _refresh();
    });
    LinkxApiClient().markNotificationsRead().catchError((_) {});
  }

  Future<void> _refresh() async {
    final next = LinkxApiClient().fetchNotifications();
    setState(() => _future = next);
    await next;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Notifications',
      child: FutureBuilder<LinkxNotificationPage>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFAAE2B)),
            );
          }
          if (snapshot.hasError) {
            return _ChatEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load notifications',
              message: snapshot.error.toString(),
              onRefresh: _refresh,
            );
          }
          final notifications = snapshot.data?.notifications ?? const [];
          if (notifications.isEmpty) {
            return _ChatEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message:
                  'Matches, messages, events, and billing updates show here.',
              onRefresh: _refresh,
            );
          }
          return RefreshIndicator(
            color: const Color(0xFFFAAE2B),
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.readAt == null
                          ? const Color(0xFFFAAE2B)
                          : const Color(0xFFECECEC),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _notificationIcon(item.type),
                        color: const Color(0xFF00473E),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item.body),
                            if (item.createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _chatTime(item.createdAt),
                                style: const TextStyle(
                                  color: Color(0xFF71717B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

IconData _notificationIcon(String type) {
  return switch (type) {
    'match' => Icons.favorite_rounded,
    'message' => Icons.chat_bubble_rounded,
    'room' => Icons.mic_rounded,
    'event' => Icons.event_rounded,
    'billing' => Icons.workspace_premium_rounded,
    _ => Icons.notifications_rounded,
  };
}

class _LinkxHeaderLogo extends StatelessWidget {
  final double width;
  final double height;

  const _LinkxHeaderLogo({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xFFFAAE2B), BlendMode.srcIn),
      child: Image.asset(
        'assets/images/linkx_logo_white.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          'Linkx',
          style: TextStyle(
            color: Color(0xFFFAAE2B),
            fontFamily: 'Bricolage Grotesque',
            fontSize: 28,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _HomeHeroBanner extends StatelessWidget {
  const _HomeHeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: 162,
            height: 154,
            child: Image.asset(
              'assets/images/home/hero_banner_people_figma.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomRight,
            ),
          ),
          Positioned(
            left: 17,
            top: 18,
            child: _StackedAvatars(
              avatars: const [
                'assets/images/home/profile_1.png',
                'assets/images/home/profile_2.png',
                'assets/images/home/avatar_1.png',
                'assets/images/home/avatar_2.png',
              ],
              countText: '120+',
              size: 16,
            ),
          ),
          Positioned(
            left: 16,
            top: 44,
            width: 202,
            child: const Text(
              'Find your perfect vibe',
              style: TextStyle(
                color: Color(0xFF1E1E1E),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.20,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 74,
            width: 222,
            child: const Text(
              'Join 120+ Singles Online Now and\nStart Real Connections',
              style: TextStyle(
                color: Color(0xFF8A8A8A),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 111,
            width: 128,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFAAE2B),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: Text(
                  'Explore Matches',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final double? width;
  final String action;
  final VoidCallback? onAction;

  const _HomeSectionHeader({
    required this.title,
    this.width,
    this.action = 'See All',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.45,
            ),
          ),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 2.33,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.chevron_right_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomsRow extends StatelessWidget {
  final int publicCount;
  final int privateCount;

  const _RoomsRow({required this.publicCount, required this.privateCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoomCard(
            title: 'Public Room',
            description: 'Open rooms with people\nnearby',
            backgroundColor: const Color(0xFFF4F4F5),
            icon: Icons.language_rounded,
            roomCount: publicCount,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _PublicRoomPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoomCard(
            title: 'Private Room',
            description: 'Invite-only watch rooms\nnearby',
            backgroundColor: const Color(0xFFFFF1DB),
            icon: Icons.lock_outline_rounded,
            roomCount: privateCount,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _PrivateRoomPage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final String title;
  final String description;
  final Color backgroundColor;
  final IconData icon;
  final int roomCount;
  final VoidCallback onTap;

  const _RoomCard({
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.icon,
    required this.roomCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 202,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF28BC5E),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 8, height: 8),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF007D1E),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 2.4,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_2_outlined,
                        size: 12,
                        color: Color(0xFF71717B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$roomCount',
                        style: const TextStyle(
                          color: Color(0xFF71717B),
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          height: 2.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFFFAAE2B)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF09090B),
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF71717B),
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.38,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StackedAvatars(
                    avatars: const [
                      'assets/images/home/avatar_1.png',
                      'assets/images/home/avatar_2.png',
                    ],
                    countText: roomCount == 0 ? '0' : '+$roomCount',
                    size: 24,
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAAE2B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _RoomHeader({required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF15302B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF171717),
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF817C79),
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            action ??
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 24,
                    color: Color(0xFF00473E),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PublicRoomPage extends StatefulWidget {
  const _PublicRoomPage();

  @override
  State<_PublicRoomPage> createState() => _PublicRoomPageState();
}

class _PublicRoomPageState extends State<_PublicRoomPage> {
  late Future<LinkxRoomPage> _roomsFuture;
  StreamSubscription<LinkxRoomSocketEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _load();
    _subscription = LinkxChatService.instance.roomEvents.listen((event) {
      if (event.type == 'room:list:updated' && mounted) _refresh();
    });
  }

  Future<LinkxRoomPage> _load() {
    return LinkxApiClient().fetchRooms(privacy: 'public', limit: 50);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _roomsFuture = next);
    await next;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F8),
      body: Column(
        children: [
          _RoomHeader(
            title: 'Public rooms',
            subtitle: 'Drop into live conversations and meet your crowd',
            action: _RoomHeaderAction(
              icon: Icons.add_rounded,
              onTap: () async {
                final room = await Navigator.of(context).push<LinkxRoom>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const _CreateRoomPage(initialPrivacy: 'public'),
                  ),
                );
                if (room != null && context.mounted) {
                  await _refresh();
                  if (!context.mounted) return;
                  await _openRoomLobby(context, room);
                }
              },
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: FutureBuilder<LinkxRoomPage>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFAAE2B)),
                  );
                }
                if (snapshot.hasError) {
                  return _ExploreMessageState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load rooms',
                    message: snapshot.error.toString(),
                    buttonText: 'Retry',
                    onTap: _refresh,
                  );
                }
                final rooms = snapshot.data?.rooms ?? const [];
                if (rooms.isEmpty) {
                  return _ExploreMessageState(
                    icon: Icons.mic_none_rounded,
                    title: 'No public rooms yet',
                    message: 'Create the first live conversation.',
                    buttonText: 'Create room',
                    onTap: () async {
                      final room = await Navigator.of(context).push<LinkxRoom>(
                        MaterialPageRoute(
                          builder: (_) =>
                              const _CreateRoomPage(initialPrivacy: 'public'),
                        ),
                      );
                      if (room != null && context.mounted) {
                        await _refresh();
                        if (!context.mounted) return;
                        await _openRoomLobby(context, room);
                      }
                    },
                  );
                }
                return RefreshIndicator(
                  color: const Color(0xFFFAAE2B),
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _PublicRoomCard(
                        room: rooms[index],
                        onTap: () => _openRoomLobby(context, rooms[index]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicRoomCard extends StatelessWidget {
  final LinkxRoom room;
  final VoidCallback onTap;

  const _PublicRoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x0F000000)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D00473E),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _RoomAvatar(
                    imageUrl: room.host.imageUrl,
                    name: room.host.name,
                    size: 72,
                  ),
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: _RoomLivePulse(),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _LiveBadge(),
                        const SizedBox(width: 8),
                        _ViewerBadge(count: room.participantCount),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF171717),
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      room.topic.isEmpty
                          ? 'Hosted by ${room.host.name}'
                          : room.topic,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF716D69),
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${room.participantCount} of ${room.maxParticipants} joined',
                      style: const TextStyle(
                        color: Color(0xFF00473E),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAAE2B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoomHeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAAE2B),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _RoomLivePulse extends StatelessWidget {
  const _RoomLivePulse();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF20D56B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.mic_rounded, size: 10, color: Colors.white),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF54047),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ViewerBadge extends StatelessWidget {
  final int count;

  const _ViewerBadge({this.count = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.groups_2_outlined,
            size: 14,
            color: Color(0xFF00473E),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF00473E),
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateRoomPage extends StatefulWidget {
  const _PrivateRoomPage();

  @override
  State<_PrivateRoomPage> createState() => _PrivateRoomPageState();
}

class _PrivateRoomPageState extends State<_PrivateRoomPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _joining = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final code = _controllers.map((controller) => controller.text).join();
    if (code.length != 6 || _joining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-character code.')),
      );
      return;
    }
    setState(() => _joining = true);
    try {
      final room = await LinkxApiClient().joinPrivateRoom(code);
      if (!mounted) return;
      await _openRoomLobby(context, room);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF8F5F6),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _RoomHeader(
              title: 'Private rooms',
              subtitle: 'Join safely with a six-character invite code',
              action: _RoomHeaderAction(
                icon: Icons.add_rounded,
                onTap: () async {
                  final room = await Navigator.of(context).push<LinkxRoom>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const _CreateRoomPage(initialPrivacy: 'private'),
                    ),
                  );
                  if (room != null && context.mounted) {
                    await _openRoomLobby(context, room);
                  }
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF073F37), Color(0xFF0D685A)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2900473E),
                          blurRadius: 30,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFFFAAE2B),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Enter your invite code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Private rooms stay hidden from discovery. Ask the host for the code and join instantly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFBFD8D2),
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: List.generate(6, (index) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == 5 ? 0 : 8,
                                ),
                                child: SizedBox(
                                  height: 58,
                                  child: TextField(
                                    controller: _controllers[index],
                                    focusNode: _nodes[index],
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp('[a-zA-Z0-9]'),
                                      ),
                                    ],
                                    style: const TextStyle(
                                      color: Color(0xFF15302B),
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.zero,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFFAAE2B),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      final normalized = value.toUpperCase();
                                      if (value != normalized) {
                                        _controllers[index]
                                          ..text = normalized
                                          ..selection = TextSelection.collapsed(
                                            offset: normalized.length,
                                          );
                                      }
                                      if (normalized.isNotEmpty && index < 5) {
                                        _nodes[index + 1].requestFocus();
                                      }
                                      if (normalized.isEmpty && index > 0) {
                                        _nodes[index - 1].requestFocus();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _joining ? null : _joinRoom,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFAAE2B),
                              foregroundColor: const Color(0xFF15302B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: _joining
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF15302B),
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _joining ? 'Joining room...' : 'Join room',
                              style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () async {
                        final room = await Navigator.of(context)
                            .push<LinkxRoom>(
                              MaterialPageRoute(
                                builder: (_) => const _CreateRoomPage(
                                  initialPrivacy: 'private',
                                ),
                              ),
                            );
                        if (room != null && context.mounted) {
                          await _openRoomLobby(context, room);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0x0F000000)),
                        ),
                        child: const Row(
                          children: [
                            _PrivateRoomCreateIcon(),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Host your own private room',
                                    style: TextStyle(
                                      color: Color(0xFF171717),
                                      fontFamily: 'Bricolage Grotesque',
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Create an invite-only audio or video space.',
                                    style: TextStyle(
                                      color: Color(0xFF817C79),
                                      fontFamily: 'Bricolage Grotesque',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF00473E),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateRoomCreateIcon extends StatelessWidget {
  const _PrivateRoomCreateIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF1DB),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.lock_person_rounded, color: Color(0xFFFAAE2B)),
    );
  }
}

Future<void> _openRoomLobby(BuildContext context, LinkxRoom room) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => _RoomLobbyPage(initialRoom: room)),
  );
}

class _CreateRoomPage extends StatefulWidget {
  final String initialPrivacy;

  const _CreateRoomPage({this.initialPrivacy = 'public'});

  @override
  State<_CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<_CreateRoomPage> {
  final _title = TextEditingController();
  final _topic = TextEditingController();
  late String _privacy;
  double _capacity = 12;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _privacy = widget.initialPrivacy;
  }

  Future<void> _create() async {
    if (_title.text.trim().length < 3 || _creating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a room title with 3 characters.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final room = await LinkxApiClient().createRoom(
        title: _title.text.trim(),
        topic: _topic.text.trim(),
        privacy: _privacy,
        maxParticipants: _capacity.round(),
      );
      if (mounted) Navigator.of(context).pop(room);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Create room',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const Text(
            'Start a live space',
            style: TextStyle(
              color: Color(0xFF171717),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose who can join, set the vibe, and invite people into an audio or video room.',
            style: TextStyle(
              color: Color(0xFF817C79),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x0F000000)),
            ),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'public',
                  icon: Icon(Icons.public_rounded),
                  label: Text('Public'),
                ),
                ButtonSegment(
                  value: 'private',
                  icon: Icon(Icons.lock_outline_rounded),
                  label: Text('Private'),
                ),
              ],
              selected: {_privacy},
              onSelectionChanged: (value) {
                setState(() => _privacy = value.first);
              },
            ),
          ),
          const SizedBox(height: 22),
          _AccountTextField(controller: _title, label: 'Room title'),
          _AccountTextField(
            controller: _topic,
            label: 'What will you talk about?',
            maxLines: 3,
            maxLength: 180,
          ),
          const SizedBox(height: 8),
          Text(
            'Capacity: ${_capacity.round()} people',
            style: const TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            value: _capacity,
            min: 2,
            max: 50,
            divisions: 48,
            activeColor: const Color(0xFFFAAE2B),
            onChanged: (value) => setState(() => _capacity = value),
          ),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: _privacy == 'private'
                  ? const Color(0xFFFFF1DB)
                  : const Color(0xFFE9F8EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _privacy == 'private'
                      ? Icons.lock_rounded
                      : Icons.public_rounded,
                  color: const Color(0xFF00473E),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _privacy == 'private'
                        ? 'A private invite code will be created. Only people with the code can join.'
                        : 'Your room appears in public discovery and anyone can join until it is full.',
                    style: const TextStyle(
                      color: Color(0xFF3F4A46),
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _creating ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFAAE2B),
              foregroundColor: const Color(0xFF00473E),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.video_call_rounded),
            label: Text(
              _creating ? 'Creating...' : 'Create media room',
              style: const TextStyle(
                fontFamily: 'Bricolage Grotesque',
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomLobbyPage extends StatefulWidget {
  final LinkxRoom initialRoom;

  const _RoomLobbyPage({required this.initialRoom});

  @override
  State<_RoomLobbyPage> createState() => _RoomLobbyPageState();
}

class _RoomLobbyPageState extends State<_RoomLobbyPage> {
  late LinkxRoom _room;
  StreamSubscription<LinkxRoomSocketEvent>? _subscription;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    LinkxChatService.instance.subscribeRoom(_room.id);
    _subscription = LinkxChatService.instance.roomEvents.listen(_handleEvent);
    _refresh();
  }

  void _handleEvent(LinkxRoomSocketEvent event) {
    if (!mounted || event.roomId != _room.id) return;
    if (event.type == 'room:ended' || event.type == 'room:removed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            event.type == 'room:ended'
                ? 'The host ended this room.'
                : 'You were removed from this room.',
          ),
        ),
      );
      Navigator.of(context).pop();
      return;
    }
    if (event.type == 'room:updated') _refresh();
  }

  Future<void> _refresh() async {
    try {
      final room = await LinkxApiClient().fetchRoom(_room.id);
      if (mounted) setState(() => _room = room);
    } catch (_) {}
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final room = await LinkxApiClient().joinRoom(_room.id);
      if (mounted) setState(() => _room = room);
      await LinkxChatService.instance.subscribeRoom(_room.id);
    } catch (error) {
      if (mounted) _showProfileAction(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterRoomCall({required bool video}) async {
    await LinkxCallService.instance.uninitialize();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinkxRoomAudioPage(room: _room, video: video),
      ),
    );
    LinkxCallService.instance.initializeForSignedInUser().catchError((_) {});
    if (!mounted) return;
    try {
      await _refresh();
    } catch (_) {}
  }

  Future<void> _leaveOrEnd() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_room.isHost ? 'End this room?' : 'Leave this room?'),
        content: Text(
          _room.isHost
              ? 'Everyone will be disconnected and the room will close.'
              : 'You can rejoin public rooms while they remain live.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_room.isHost ? 'End room' : 'Leave'),
          ),
        ],
      ),
    );
    if (shouldContinue != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (_room.isHost) {
        await LinkxApiClient().endRoom(_room.id);
      } else {
        await LinkxApiClient().leaveRoom(_room.id);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showProfileAction(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(LinkxRoomMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${member.user.name}?'),
        content: const Text('They will lose access to this live room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LinkxApiClient().removeRoomMember(_room.id, member.user.id);
    await _refresh();
  }

  @override
  void dispose() {
    LinkxChatService.instance.unsubscribeRoom(_room.id);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F8),
        surfaceTintColor: Colors.transparent,
        title: const Text('Room lobby'),
        actions: [
          if (_room.isJoined)
            IconButton(
              tooltip: _room.isHost ? 'End room' : 'Leave room',
              onPressed: _busy ? null : _leaveOrEnd,
              icon: Icon(
                _room.isHost
                    ? Icons.stop_circle_outlined
                    : Icons.logout_rounded,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _room.privacy == 'private'
                    ? const [Color(0xFFFFF1DB), Color(0xFFFFE2B6)]
                    : const [Color(0xFFEAF8EF), Color(0xFFD4F1E0)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _LiveBadge(),
                    const Spacer(),
                    Icon(
                      _room.privacy == 'private'
                          ? Icons.lock_outline_rounded
                          : Icons.public_rounded,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _room.title,
                  style: const TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_room.topic.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _room.topic,
                    style: const TextStyle(
                      color: Color(0xFF52525B),
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    _RoomAvatar(
                      imageUrl: _room.host.imageUrl,
                      name: _room.host.name,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Hosted by ${_room.host.name}')),
                    Text(
                      '${_room.participantCount}/${_room.maxParticipants}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_room.privacy == 'private' &&
              _room.inviteCode != null &&
              _room.isJoined) ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('Private invite code'),
                subtitle: Text(
                  _room.inviteCode!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _room.inviteCode!),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'People in this room',
                  style: TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${_room.members.length} live'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final member in _room.members)
                  ListTile(
                    leading: _RoomAvatar(
                      imageUrl: member.user.imageUrl,
                      name: member.user.name,
                      size: 42,
                    ),
                    title: Text(member.user.name),
                    subtitle: Text(
                      member.role == 'host' ? 'Host' : 'Participant',
                    ),
                    trailing: _room.isHost && member.user.id != _room.host.id
                        ? IconButton(
                            tooltip: 'Remove participant',
                            onPressed: () => _removeMember(member),
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              color: Colors.red,
                            ),
                          )
                        : member.role == 'host'
                        ? const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFFAAE2B),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!_room.isJoined)
            FilledButton.icon(
              onPressed: _busy ? null : _join,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFAAE2B),
                foregroundColor: const Color(0xFF00473E),
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.login_rounded),
              label: Text(_busy ? 'Joining...' : 'Join room'),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _enterRoomCall(video: false),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00473E),
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Color(0x3300473E)),
                    ),
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('Audio room'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _enterRoomCall(video: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00473E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Video room'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Use audio for quick talks or video for face-to-face rooms. Public and private access rules stay the same.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double size;

  const _RoomAvatar({
    required this.imageUrl,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFFFE7B8),
      backgroundImage: imageUrl.isEmpty ? null : _linkxImageProvider(imageUrl),
      child: imageUrl.isEmpty
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF00473E),
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _EventsRow extends StatefulWidget {
  const _EventsRow();

  @override
  State<_EventsRow> createState() => _EventsRowState();
}

class _EventsRowState extends State<_EventsRow> {
  late Future<LinkxEventPage> _future;

  @override
  void initState() {
    super.initState();
    _future = LinkxApiClient().fetchEvents(limit: 10);
  }

  Future<void> _refresh() async {
    final next = LinkxApiClient().fetchEvents(limit: 10);
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkxEventPage>(
      future: _future,
      builder: (context, snapshot) {
        final events = snapshot.data?.events ?? const <LinkxEvent>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            events.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFAAE2B)),
            ),
          );
        }
        if (snapshot.hasError) {
          return _InlineHomeError(message: snapshot.error.toString());
        }
        if (events.isEmpty) {
          return _InlineHomeError(
            message: 'No upcoming events yet. Add events from the backend API.',
            action: _refresh,
          );
        }
        return SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _EventCard(event: events[index], onChanged: _refresh);
            },
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final LinkxEvent event;
  final Future<void> Function() onChanged;

  const _EventCard({required this.event, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _EventDetailPage(initialEvent: event),
          ),
        );
        if (changed == true) await onChanged();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: event.coverImageUrl.isNotEmpty
                  ? Image.network(
                      event.coverImageUrl,
                      width: double.infinity,
                      height: 125,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      'assets/images/home/event_concert.png',
                      width: double.infinity,
                      height: 125,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF09090B),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 3),
            _EventInfo(
              icon: Icons.calendar_month_outlined,
              label: event.startAt == null
                  ? 'Date coming soon'
                  : DateFormat('MMM d, yyyy').format(event.startAt!),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: _EventInfo(
                    icon: Icons.location_on_outlined,
                    label: event.venue.isEmpty ? 'Online' : event.venue,
                  ),
                ),
                _EventAttendeeBadge(count: event.attendeeCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailPage extends StatefulWidget {
  final LinkxEvent initialEvent;

  const _EventDetailPage({required this.initialEvent});

  @override
  State<_EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<_EventDetailPage> {
  late LinkxEvent _event;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _event = widget.initialEvent;
  }

  Future<void> _toggleRsvp() async {
    setState(() => _saving = true);
    try {
      final event = _event.isGoing
          ? await LinkxApiClient().cancelEventRsvp(_event.id)
          : await LinkxApiClient().rsvpEvent(_event.id);
      if (mounted) setState(() => _event = event);
    } catch (error) {
      if (mounted) _showProfileAction(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountPageShell(
      title: 'Event',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: _event.coverImageUrl.isNotEmpty
                ? Image.network(
                    _event.coverImageUrl,
                    height: 220,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/images/home/event_concert.png',
                    height: 220,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            _event.title,
            style: const TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _EventInfo(
            icon: Icons.calendar_month_outlined,
            label: _event.startAt == null
                ? 'Date coming soon'
                : DateFormat(
                    'EEEE, MMM d, yyyy • h:mm a',
                  ).format(_event.startAt!),
          ),
          const SizedBox(height: 8),
          _EventInfo(
            icon: Icons.location_on_outlined,
            label: _event.venue.isEmpty ? 'Online' : _event.venue,
          ),
          const SizedBox(height: 16),
          Text(
            _event.description.isEmpty
                ? 'More event details will be available soon.'
                : _event.description,
            style: const TextStyle(height: 1.55),
          ),
          const SizedBox(height: 20),
          Text('${_event.attendeeCount}/${_event.capacity} going'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _toggleRsvp,
            style: FilledButton.styleFrom(
              backgroundColor: _event.isGoing
                  ? const Color(0xFF00473E)
                  : const Color(0xFFFAAE2B),
              foregroundColor: _event.isGoing
                  ? Colors.white
                  : const Color(0xFF00473E),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: Icon(
              _event.isGoing ? Icons.check_rounded : Icons.event_available,
            ),
            label: Text(
              _saving
                  ? 'Saving...'
                  : _event.isGoing
                  ? 'Going'
                  : 'RSVP',
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineHomeError extends StatelessWidget {
  final String message;
  final Future<void> Function()? action;

  const _InlineHomeError({required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_busy_rounded, color: Color(0xFFA98CAA)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (action != null)
            TextButton(onPressed: action, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _EventAttendeeBadge extends StatelessWidget {
  final int count;

  const _EventAttendeeBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAAE2B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_outlined, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF71717B)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF71717B),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _StackedAvatars extends StatelessWidget {
  final List<String> avatars;
  final String countText;
  final double size;

  const _StackedAvatars({
    required this.avatars,
    required this.countText,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * (avatars.length * 0.55 + 1.2),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < avatars.length; index++)
            Positioned(
              left: index * size * 0.42,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF4F4F5), width: 2),
                  image: DecorationImage(
                    image: AssetImage(avatars[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Positioned(
            left: avatars.length * size * 0.42,
            child: Container(
              height: size,
              constraints: BoxConstraints(minWidth: size),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFAAE2B),
                border: Border.all(color: const Color(0xFFF4F4F5), width: 2),
                borderRadius: BorderRadius.circular(size),
              ),
              child: Text(
                countText,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: size <= 16 ? 7 : 8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  final List<_ProfileData> profiles;
  final bool homeScale;

  const _ProfileGrid({required this.profiles, required this.homeScale});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: homeScale ? 34 : 22,
          children: [
            for (final profile in profiles)
              _ProfileCard(
                profile: profile,
                width: cardWidth,
                imageHeight: homeScale ? 150 : 150,
                titleSize: homeScale ? 21 : 16,
                metaSize: homeScale ? 17 : 14,
              ),
          ],
        );
      },
    );
  }
}

class _ExploreLoadingState extends StatelessWidget {
  const _ExploreLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Center(child: CircularProgressIndicator(color: Color(0xFFFAAE2B))),
    );
  }
}

class _ExploreMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final Future<void> Function() onTap;

  const _ExploreMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00473E), size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF777370),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00473E),
              backgroundColor: const Color(0xFFFAAE2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final _ProfileData profile;
  final double width;
  final double imageHeight;
  final double titleSize;
  final double metaSize;

  const _ProfileCard({
    required this.profile,
    required this.width,
    required this.imageHeight,
    required this.titleSize,
    required this.metaSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ExploreProfileDetailPage(profile: profile),
          ),
        );
      },
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image(
                image: _linkxImageProvider(profile.image),
                width: width,
                height: imageHeight,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Bricolage Grotesque',
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  profile.ageLabel,
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: metaSize,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.location_on_outlined,
                  size: metaSize + 2,
                  color: const Color(0xFF679C95),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    profile.distance == null
                        ? profile.location
                        : '${profile.distance}miles Aw...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: metaSize,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreProfileDetailPage extends StatelessWidget {
  final _ProfileData profile;

  const _ExploreProfileDetailPage({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F8),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExploreDetailTopBar(profile: profile),
                    const SizedBox(height: 18),
                    _ExploreDetailHero(profile: profile),
                    const SizedBox(height: 18),
                    _ExploreContactActions(profile: profile),
                    const SizedBox(height: 18),
                    _ExploreProfileInfo(profile: profile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreDetailTopBar extends StatelessWidget {
  final _ProfileData profile;

  const _ExploreDetailTopBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircularIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
        const Spacer(),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFECECEC)),
          ),
          child: Text(
            profile.distance == null
                ? profile.location
                : '${profile.distance} miles away',
            style: const TextStyle(
              color: Color(0xFF00473E),
              fontFamily: 'Bricolage Grotesque',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CircularIconButton(
          icon: Icons.more_horiz_rounded,
          onTap: () => _showProfileOptions(context, profile),
        ),
      ],
    );
  }
}

class _ExploreDetailHero extends StatelessWidget {
  final _ProfileData profile;

  const _ExploreDetailHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Image(
              image: _linkxImageProvider(profile.image),
              width: double.infinity,
              height: 438,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.age == null
                            ? profile.name
                            : '${profile.name}, ${profile.age}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF20D56B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: Color(0xFF679C95),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        profile.locationLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF777370),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreContactActions extends StatelessWidget {
  final _ProfileData profile;

  const _ExploreContactActions({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContactActionButton(
            label: 'Call',
            icon: Icons.call_rounded,
            color: const Color(0xFF00473E),
            onTap: () => _startZegoCall(context, isVideoCall: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ContactActionButton(
            label: 'Video',
            icon: Icons.videocam_rounded,
            color: const Color(0xFFFAAE2B),
            onTap: () => _startZegoCall(context, isVideoCall: true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ContactActionButton(
            label: 'Chat',
            icon: Icons.chat_bubble_rounded,
            color: const Color(0xFFFF3F7A),
            onTap: () {
              if (!profile.isMatched) {
                _showProfileAction(
                  context,
                  'You can only chat after you both like each other.',
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _ChatDetailPage(
                    chat: _ChatData(
                      profile.image,
                      profile.name,
                      'Say hi and start the conversation.',
                      'now',
                      userId: profile.id,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _startZegoCall(
    BuildContext context, {
    required bool isVideoCall,
  }) async {
    if (!profile.isMatched) {
      _showProfileAction(
        context,
        'You can only call after you both like each other.',
      );
      return;
    }
    final result = await LinkxCallService.instance.startCall(
      targetUserId: profile.id,
      targetUserName: profile.name,
      isVideoCall: isVideoCall,
    );
    if (!context.mounted || result.success) return;
    _showProfileAction(context, result.message ?? 'Unable to start call.');
  }
}

class _ContactActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ContactActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          height: 74,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreProfileInfo extends StatelessWidget {
  final _ProfileData profile;

  const _ExploreProfileInfo({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          _ProfileInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: profile.name,
          ),
          const SizedBox(height: 12),
          _ProfileInfoRow(
            icon: Icons.cake_outlined,
            label: 'Age',
            value: profile.ageLabel,
          ),
          const SizedBox(height: 12),
          _ProfileInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: profile.locationLine,
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF00473E), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF777370),
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircularIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: const Color(0xFF00473E), size: 20),
        ),
      ),
    );
  }
}

void _showProfileAction(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
}

Future<void> _showProfileOptions(
  BuildContext context,
  _ProfileData profile,
) async {
  if (profile.id.isEmpty) {
    _showProfileAction(context, 'This demo profile has no account actions.');
    return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profile.isMatched)
              ListTile(
                leading: const Icon(Icons.heart_broken_outlined),
                title: const Text('Unmatch'),
                onTap: () => Navigator.pop(context, 'unmatch'),
              ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('Block'),
              onTap: () => Navigator.pop(context, 'block'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('Report'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;

  try {
    if (action == 'unmatch') {
      await LinkxApiClient().unmatchUser(profile.id);
      if (!context.mounted) return;
      _showProfileAction(context, '${profile.name} was unmatched.');
      Navigator.maybePop(context);
      return;
    }
    if (action == 'block') {
      await LinkxApiClient().blockUser(profile.id);
      if (!context.mounted) return;
      _showProfileAction(context, '${profile.name} was blocked.');
      Navigator.maybePop(context);
      return;
    }
    if (action == 'report') {
      await _showReportDialog(context, profile);
    }
  } catch (error) {
    if (context.mounted) _showProfileAction(context, error.toString());
  }
}

Future<void> _showReportDialog(
  BuildContext context,
  _ProfileData profile,
) async {
  final detailsController = TextEditingController();
  var reason = 'inappropriate_content';
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Report ${profile.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  items: const [
                    DropdownMenuItem(
                      value: 'inappropriate_content',
                      child: Text('Inappropriate content'),
                    ),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text('Harassment'),
                    ),
                    DropdownMenuItem(
                      value: 'fake_profile',
                      child: Text('Fake profile'),
                    ),
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(
                      value: 'underage',
                      child: Text('Underage user'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
  if (submitted == true) {
    await LinkxApiClient().reportUser(
      userId: profile.id,
      reason: reason,
      details: detailsController.text.trim(),
    );
    if (context.mounted) {
      _showProfileAction(context, 'Report submitted for review.');
    }
  }
  detailsController.dispose();
}

class _ProfileData {
  final String id;
  final String image;
  final String name;
  final int? age;
  final int? distance;
  final String location;
  final String lookingFor;
  final List<String> interests;
  final String identity;
  final String relationshipStatus;

  const _ProfileData(
    this.image,
    this.name,
    this.age,
    this.distance, {
    this.id = '',
    this.location = 'Nearby',
    this.lookingFor = '',
    this.interests = const [],
    this.identity = '',
    this.relationshipStatus = 'none',
  });

  factory _ProfileData.fromExploreUser(LinkxExploreUser user) {
    return _ProfileData(
      user.imageUrl,
      user.name,
      user.age,
      user.distanceMiles,
      id: user.id,
      location: user.location,
      lookingFor: user.lookingFor,
      interests: user.interests,
      identity: user.identity,
      relationshipStatus: user.relationshipStatus,
    );
  }

  String get ageLabel => age == null ? 'Age' : '$age Years';
  bool get isMatched => relationshipStatus == 'matched';

  String get locationLine {
    final distanceText = distance == null ? null : '$distance miles away';
    final cleanLocation = location.trim();
    if (distanceText == null) {
      return cleanLocation.isEmpty ? 'Nearby' : cleanLocation;
    }
    if (cleanLocation.isEmpty || cleanLocation == 'Nearby') return distanceText;
    return '$distanceText • $cleanLocation';
  }
}

ImageProvider _linkxImageProvider(String image) {
  final trimmed = image.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }
  return AssetImage(trimmed);
}
