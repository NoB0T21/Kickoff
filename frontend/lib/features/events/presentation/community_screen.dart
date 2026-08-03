import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';
import '../../../core/widgets/skeleton.dart';
import 'package:kickoff/features/profile/presentation/providers/profile_providers.dart';
import 'package:kickoff/features/events/domain/event_model.dart';
import 'package:kickoff/features/events/presentation/providers/event_providers.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';

  List<Map<String, dynamic>> _recommendedPlayers = [];
  bool _isLoadingRecommendations = true;
  String _recError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final apiClient = ref.read(apiClientProvider);

    setState(() {
      _isLoadingRecommendations = true;
      _recError = '';
    });

    try {
      // Fetch following list
      final followingResponse = await apiClient.get('/api/profiles/$currentUserId/following');
      final followingData = followingResponse.data as Map<String, dynamic>;
      final List<dynamic> followingList = followingData['data'] ?? [];

      // Fetch followers list
      final followersResponse = await apiClient.get('/api/profiles/$currentUserId/followers');
      final followersData = followersResponse.data as Map<String, dynamic>;
      final List<dynamic> followersList = followersData['data'] ?? [];

      // Merge and deduplicate recommendations
      final Map<String, Map<String, dynamic>> uniquePlayers = {};
      
      for (final item in followingList) {
        final mapItem = item as Map<String, dynamic>;
        uniquePlayers[mapItem['id'] as String] = {
          ...mapItem,
          'is_following': true,
          'is_follower': false,
        };
      }

      for (final item in followersList) {
        final mapItem = item as Map<String, dynamic>;
        final id = mapItem['id'] as String;
        if (uniquePlayers.containsKey(id)) {
          uniquePlayers[id]!['is_follower'] = true;
        } else {
          uniquePlayers[id] = {
            ...mapItem,
            'is_following': false,
            'is_follower': true,
          };
        }
      }

      final filteredPlayers = uniquePlayers.values.where((p) => p['is_follower'] == true).toList();

      if (mounted) {
        setState(() {
          _recommendedPlayers = filteredPlayers;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recError = 'Failed to load player recommendations: $e';
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _searchPlayers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      // Query profiles case-insensitively using Supabase Client
      final response = await supabase
          .from('profiles')
          .select('*')
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(25);

      final List<dynamic> data = response as List<dynamic>;

      // Determine follow status for search results
      final List<Map<String, dynamic>> results = [];
      for (final item in data) {
        final profile = item as Map<String, dynamic>;
        final profileId = profile['id'] as String;

        if (profileId == currentUserId) continue; // Skip self

        // Check if we are already following this user in our recommendations
        final isFollowing = _recommendedPlayers.any((p) => p['id'] == profileId && p['is_following'] == true);

        results.add({
          'id': profileId,
          'username': profile['username'],
          'full_name': profile['full_name'],
          'avatar_url': profile['avatar_url'],
          'is_following': isFollowing,
        });
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Error searching profiles: $e';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> player) async {
    final repo = ref.read(profileRepositoryProvider);
    final targetId = player['id'] as String;
    final isFollowing = player['is_following'] as bool;

    try {
      if (isFollowing) {
        await repo.unfollowUser(targetId);
      } else {
        await repo.followUser(targetId);
      }
      
      // Reload recommendations to fetch updated state
      await _loadRecommendations();
      
      // Update search results list if open
      if (_searchResults.isNotEmpty) {
        setState(() {
          for (var p in _searchResults) {
            if (p['id'] == targetId) {
              p['is_following'] = !isFollowing;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventsState = ref.watch(eventListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'COMMUNITY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGreen,
          labelColor: AppTheme.accentGreen,
          unselectedLabelColor: Colors.grey.shade500,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'FIND MATCHES', icon: Icon(Icons.sports_soccer)),
            Tab(text: 'FIND PLAYERS', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Find Matches (Events) ──
          RefreshIndicator(
            onRefresh: () => ref.read(eventListProvider.notifier).search(),
            child: eventsState.isLoading && eventsState.events.isEmpty
                ? const EventListSkeleton()
                : eventsState.error != null
                    ? _buildErrorView(eventsState.error!)
                    : eventsState.events.isEmpty
                        ? _buildEmptyMatchesView()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: eventsState.events.length,
                            itemBuilder: (context, index) {
                              final event = eventsState.events[index];
                              return _buildEventCard(context, event);
                            },
                          ),
          ),

          // ── Tab 2: Find Players (Community Profiles) ──
          Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _searchPlayers(val),
                  decoration: InputDecoration(
                    hintText: 'Search player username or full name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchPlayers('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _searchController.text.isNotEmpty
                    ? _buildSearchResultsList()
                    : _buildRecommendationsList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    String privacyLabel = event.privacy == EventPrivacy.private ? 'Private' : 'Public';
    Color privacyColor = event.privacy == EventPrivacy.private ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/events/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: privacyColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      privacyLabel.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: privacyColor),
                    ),
                  ),
                  Text(
                    event.sport,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  event.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.turfName ?? 'Turf Ground',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        '${event.startsAt.day}/${event.startsAt.month} at ${event.startsAt.hour}:00',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Max ${event.capacity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    if (_isSearching) {
      return const PlayerListSkeleton();
    }

    if (_searchError.isNotEmpty) {
      return Center(child: Text(_searchError, style: const TextStyle(color: Colors.red)));
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('No players match your search', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final player = _searchResults[index];
        return _buildPlayerListTile(player);
      },
    );
  }

  Widget _buildRecommendationsList() {
    if (_isLoadingRecommendations) {
      return const PlayerListSkeleton();
    }

    if (_recError.isNotEmpty) {
      return Center(child: Text(_recError, style: const TextStyle(color: Colors.red)));
    }

    if (_recommendedPlayers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Build Your Network',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Search for players to follow them. Roster recommendations will show here once you follow users or they follow you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recommendedPlayers.length,
      itemBuilder: (context, index) {
        final player = _recommendedPlayers[index];
        return _buildPlayerListTile(player, showRelation: true);
      },
    );
  }

  Widget _buildPlayerListTile(Map<String, dynamic> player, {bool showRelation = false}) {
    final displayName = (player['full_name'] as String?)?.isNotEmpty == true
        ? player['full_name'] as String
        : player['username'] as String;
    
    final username = player['username'] as String;
    final isFollowing = player['is_following'] as bool;
    final isFollower = player['is_follower'] as bool? ?? false;

    String relationLabel = '';
    if (showRelation) {
      if (isFollowing && isFollower) {
        relationLabel = 'Mutual Follow';
      } else if (isFollowing) {
        relationLabel = 'Following';
      } else if (isFollower) {
        relationLabel = 'Follows You';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      borderOnForeground: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: () => context.go('/profile/${player['id']}'),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
          ),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('@$username', style: const TextStyle(fontSize: 11)),
            if (relationLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                relationLabel,
                style: TextStyle(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        trailing: OutlinedButton(
          onPressed: () => _toggleFollow(player),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: isFollowing ? Colors.grey : AppTheme.primaryGreen),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            isFollowing ? 'Unfollow' : 'Follow',
            style: TextStyle(
              color: isFollowing ? Colors.grey : AppTheme.primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load matches', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMatchesView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Matches Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'There are no active public matches. Check back later or host your own!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
