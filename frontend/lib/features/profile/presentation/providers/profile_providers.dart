import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kickoff/features/profile/data/profile_repository.dart';
import 'package:kickoff/features/profile/domain/profile_model.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';

// ── Profile Repository Provider ──

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(apiClient: ref.watch(apiClientProvider));
});

// ── Current User's Profile State ──

class ProfileState {
  final ProfileModel? profile;
  final bool isLoading;
  final String? errorMessage;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileModel? profile,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref);
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref _ref;

  ProfileNotifier(this._ref) : super(const ProfileState());

  Future<void> loadMyProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(profileRepositoryProvider);
      final profile = await repo.getMyProfile();
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e, stackTrace) {
      final errMsg = _friendlyError(e);
      print('[ProfileNotifier] Load my profile failed: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: errMsg);
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? primarySport,
    String? skillLevel,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(profileRepositoryProvider);
      final updated = await repo.updateProfile(
        username: username,
        fullName: fullName,
        avatarUrl: avatarUrl,
        primarySport: primarySport,
        skillLevel: skillLevel,
      );
      state = state.copyWith(isLoading: false, profile: updated);
    } catch (e, stackTrace) {
      final errMsg = _friendlyError(e);
      print('[ProfileNotifier] Update profile failed: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: errMsg);
      rethrow;
    }
  }

  Future<String> uploadAvatar(File imageFile, {String? oldAvatarUrl}) async {
    final repo = _ref.read(profileRepositoryProvider);
    return await repo.uploadAvatar(imageFile, oldAvatarUrl: oldAvatarUrl);
  }

  void clear() {
    state = const ProfileState();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('DioException') || msg.contains('SocketException') || msg.contains('connection timeout')) {
      return 'Connection timed out. Verify backend is running and accessible.';
    }
    return msg;
  }
}

// ── Username Availability Check ──

final usernameAvailabilityProvider =
    FutureProvider.family<bool, String>((ref, username) async {
  if (username.length < 3) return false;
  final repo = ref.read(profileRepositoryProvider);
  return await repo.checkUsername(username);
});

// ── View another user's profile ──

final viewProfileProvider =
    FutureProvider.family<ProfileModel, String>((ref, userId) async {
  final repo = ref.read(profileRepositoryProvider);
  return await repo.getProfile(userId);
});
