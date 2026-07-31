import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      body: CustomScrollView(
        slivers: [
          // ── App Bar with gradient ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
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
                            ),
                            _divider(),
                            _StatItem(
                              value: profile.followingCount.toString(),
                              label: 'Following',
                              icon: Icons.person_add,
                              color: AppTheme.accentGreen,
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
                          child: ElevatedButton(
                            onPressed: () {
                              // Follow/unfollow logic will be wired later
                            },
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
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
