import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';
import 'package:kickoff/features/profile/presentation/providers/profile_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Avatar
  File? _avatarFile;
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  // Sport & Skill
  String _selectedSport = 'Football';
  String _selectedSkill = 'Beginner';

  // Username check
  Timer? _usernameDebounce;
  bool? _usernameAvailable;
  bool _checkingUsername = false;

  bool _submitting = false;

  final _sports = ['Football', 'Cricket', 'Badminton', 'Basketball', 'Tennis'];
  final _skillLevels = ['Beginner', 'Intermediate', 'Advanced', 'Semi-Pro'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentUser = await ref.read(authRepositoryProvider).currentUser;
      if (currentUser != null) {
        final meta = currentUser.userMetadata;
        if (meta != null && mounted) {
          setState(() {
            final fullName = meta['full_name'] ?? meta['name'];
            if (fullName is String && fullName.isNotEmpty) {
              _fullNameController.text = fullName;
            }
            final avatar = meta['avatar_url'] ?? meta['picture'];
            if (avatar is String && avatar.isNotEmpty) {
              _avatarUrl = avatar;
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: index <= _currentPage
                            ? AppTheme.primaryGreen
                            : Colors.grey.shade300,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildAvatarPage(theme),
                  _buildProfilePage(theme),
                  _buildSportPage(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Avatar ──
  Widget _buildAvatarPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Add a Profile Photo',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Help others recognize you on the field',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),

          // Avatar Picker
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      width: 3,
                    ),
                    image: _avatarFile != null
                        ? DecorationImage(
                            image: FileImage(_avatarFile!),
                            fit: BoxFit.cover,
                          )
                        : (_avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null),
                  ),
                  child: (_avatarFile == null && _avatarUrl == null)
                      ? const Icon(Icons.person, size: 60, color: AppTheme.primaryGreen)
                      : null,
                ),
                if (_uploadingAvatar)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Next/Skip
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToPage(1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_avatarFile != null || _avatarUrl != null) ? () => _goToPage(1) : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Next', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Page 2: Username & Full Name ──
  Widget _buildProfilePage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              'Your Profile',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a unique username and enter your name',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),

            // Username
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              onChanged: _onUsernameChanged,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'e.g. striker99',
                prefixIcon: const Icon(Icons.alternate_email),
                suffixIcon: _checkingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _usernameAvailable == null
                        ? null
                        : Icon(
                            _usernameAvailable! ? Icons.check_circle : Icons.cancel,
                            color: _usernameAvailable! ? Colors.green : Colors.red,
                          ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Choose a username';
                if (v.length < 3) return 'At least 3 characters';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return 'Letters, numbers, and underscores only';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Full Name
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Jane Doe',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your name';
                return null;
              },
            ),
            const SizedBox(height: 36),

            // Navigation
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _goToPage(0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate() && _usernameAvailable == true) {
                        _goToPage(2);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Next', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 3: Sport & Skill ──
  Widget _buildSportPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            'Your Sport',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Select your primary sport and skill level',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Sport Selection
          Text('Primary Sport', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _sports.map((sport) {
              final selected = sport == _selectedSport;
              return ChoiceChip(
                label: Text(sport),
                selected: selected,
                onSelected: (_) => setState(() => _selectedSport = sport),
                selectedColor: AppTheme.primaryGreen,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: selected ? AppTheme.primaryGreen : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Skill Level
          Text('Skill Level', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...(_skillLevels.map((level) {
            final selected = level == _selectedSkill;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedSkill = level),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppTheme.primaryGreen : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    color: selected ? AppTheme.primaryGreen.withOpacity(0.08) : theme.colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: selected ? AppTheme.primaryGreen : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        level,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppTheme.primaryGreen : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })),
          const SizedBox(height: 24),

          // Submit
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToPage(1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Complete Setup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
        _uploadingAvatar = true;
      });

      try {
        final url = await ref.read(profileProvider.notifier).uploadAvatar(_avatarFile!);
        setState(() {
          _avatarUrl = url;
          _uploadingAvatar = false;
        });
      } catch (e) {
        setState(() => _uploadingAvatar = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload avatar: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    if (value.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final repo = ref.read(profileRepositoryProvider);
        final available = await repo.checkUsername(value);
        if (mounted) {
          setState(() {
            _usernameAvailable = available;
            _checkingUsername = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _submitting = true);

    try {
      await ref.read(profileProvider.notifier).updateProfile(
            username: _usernameController.text.trim(),
            fullName: _fullNameController.text.trim(),
            avatarUrl: _avatarUrl,
            primarySport: _selectedSport,
            skillLevel: _selectedSkill,
          );

      await ref.read(authStateProvider.notifier).onOnboardingComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
