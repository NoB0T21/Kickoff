import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';
import 'package:kickoff/features/profile/domain/profile_model.dart';
import 'package:kickoff/features/profile/presentation/providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // null = view own profile

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.userId == null) {
      // Load own profile
      Future.microtask(() => ref.read(profileProvider.notifier).loadMyProfile());
    }
  }

  Future<void> _changeProfilePicture(BuildContext context, String? currentAvatarUrl) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Uploading new profile picture...'),
          ],
        ),
        duration: Duration(days: 1),
      ),
    );

    try {
      final file = File(image.path);
      final newUrl = await ref
          .read(profileProvider.notifier)
          .uploadAvatar(file, oldAvatarUrl: currentAvatarUrl);

      await ref.read(profileProvider.notifier).updateProfile(avatarUrl: newUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If viewing someone else's profile, use the async provider
    if (widget.userId != null) {
      final asyncProfile = ref.watch(viewProfileProvider(widget.userId!));
      return asyncProfile.when(
        data: (profile) => _buildProfileView(theme, profile, isOwnProfile: false),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          body: Center(child: Text('Error loading profile: $e')),
        ),
      );
    }

    // Own profile
    final profileState = ref.watch(profileProvider);
    if (profileState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGreen,
          ),
        ),
      );
    }

    if (profileState.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.red.shade700,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Unable to Load Profile',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profileState.errorMessage!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(profileProvider.notifier).loadMyProfile();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = profileState.profile;
    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGreen,
          ),
        ),
      );
    }
    return _buildProfileView(theme, profile, isOwnProfile: true);
  }

  Widget _buildProfileView(ThemeData theme, ProfileModel profile, {required bool isOwnProfile}) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final headerHeight = 200.0 + topPadding;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          if (widget.userId == null) {
            await ref.read(profileProvider.notifier).loadMyProfile();
          } else {
            ref.invalidate(viewProfileProvider(widget.userId!));
            ref.invalidate(isFollowingProvider(widget.userId!));
            await ref.read(viewProfileProvider(widget.userId!).future);
            await ref.read(isFollowingProvider(widget.userId!).future);
          }
        },
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // ── App Bar with gradient ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: isOwnProfile
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
            flexibleSpace: const FlexibleSpaceBar(
              background: SizedBox.shrink(),
            ),
            actions: [
              if (isOwnProfile)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'logout') {
                      ref.read(authStateProvider.notifier).signOut();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'logout', child: Text('Sign Out')),
                  ],
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gradient Background
                Positioned(
                  top: -200 - topPadding,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryGreen,
                          AppTheme.accentGreen,
                          AppTheme.primaryGreen.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    // ── Avatar (overlapping the app bar) ──
                    Transform.translate(
                      offset: const Offset(0, -50),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                                  backgroundImage:
                                      profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                                  child: profile.avatarUrl == null
                                      ? Text(
                                          profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              if (isOwnProfile)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _changeProfilePicture(context, profile.avatarUrl),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Name & Username
                          Text(
                            profile.fullName,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${profile.username}',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sport & Skill badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Badge(
                                icon: Icons.sports,
                                label: profile.primarySport,
                                color: AppTheme.primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              _Badge(
                                icon: Icons.trending_up,
                                label: profile.skillLevel,
                                color: AppTheme.accentGreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Stats Grid ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _StatItem(
                              value: profile.totalPoints.toString(),
                              label: 'Points',
                              icon: Icons.star_rounded,
                              color: Colors.amber,
                            ),
                            _divider(),
                            _StatItem(
                              value: profile.followersCount.toString(),
                              label: 'Followers',
                              icon: Icons.people,
                              color: AppTheme.primaryGreen,
                              onTap: () => _showConnectionsBottomSheet(context, ref, profile.id, 'followers'),
                            ),
                            _divider(),
                            _StatItem(
                              value: profile.followingCount.toString(),
                              label: 'Following',
                              icon: Icons.person_add,
                              color: AppTheme.accentGreen,
                              onTap: () => _showConnectionsBottomSheet(context, ref, profile.id, 'following'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Follow/Edit Button ──
                    if (!isOwnProfile)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ref.watch(isFollowingProvider(profile.id)).when(
                            data: (isFollowing) => isFollowing
                                ? OutlinedButton(
                                    onPressed: () => _toggleFollow(context, profile.id, isFollowing),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.grey),
                                      foregroundColor: Colors.grey,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'Unfollow',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _toggleFollow(context, profile.id, isFollowing),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'Follow',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ),
                            loading: () => const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                              ),
                            ),
                            error: (err, _) => ElevatedButton(
                              onPressed: null,
                              child: Text('Error loading status: $err'),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),
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

  Widget _divider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }

  Future<void> _toggleFollow(BuildContext context, String targetUserId, bool isFollowing) async {
    final repo = ref.read(profileRepositoryProvider);
    try {
      if (isFollowing) {
        await repo.unfollowUser(targetUserId);
      } else {
        await repo.followUser(targetUserId);
      }
      ref.invalidate(isFollowingProvider(targetUserId));
      ref.invalidate(viewProfileProvider(targetUserId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update follow: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showConnectionsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String profileId,
    String type, // 'followers' or 'following'
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                type == 'followers' ? 'Followers' : 'Following',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(height: 24),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchConnections(ref, profileId, type),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    final players = snapshot.data ?? [];
                    if (players.isEmpty) {
                      return Center(
                        child: Text(
                          type == 'followers' ? 'No followers yet' : 'Not following anyone yet',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        final displayName = (player['full_name'] as String?)?.isNotEmpty == true
                            ? player['full_name'] as String
                            : player['username'] as String;
                        final username = player['username'] as String;

                        return ListTile(
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            context.push('/profile/${player['id']}'); // Navigate to profile
                          },
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('@$username', style: const TextStyle(fontSize: 12)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchConnections(WidgetRef ref, String profileId, String type) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/api/profiles/$profileId/$type');
    final data = response.data as Map<String, dynamic>;
    final List<dynamic> list = data['data'] ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
