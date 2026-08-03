import { profileRepository, ProfileRow, UpdateProfileData } from '../repositories/profileRepository.js';
import { supabaseAdmin } from '../config/supabase.js';
import { AppError } from '../middleware/errorHandler.js';

export const profileService = {
  /**
   * Get a profile by ID. Throws 404 if not found or soft-deleted.
   */
  async getProfile(id: string): Promise<ProfileRow> {
    const profile = await profileRepository.findById(id);
    if (!profile) {
      throw new AppError(404, 'PROFILE_NOT_FOUND', 'Profile not found.');
    }
    return profile;
  },

  /**
   * Get the authenticated user's own profile.
   */
  async getMyProfile(userId: string): Promise<ProfileRow> {
    return this.getProfile(userId);
  },

  /**
   * Update profile fields. Handles username uniqueness and onboarding flag.
   */
  async updateProfile(userId: string, data: UpdateProfileData): Promise<ProfileRow> {
    // If username is being changed, do a pre-check (the DB constraint is the real source of truth)
    if (data.username) {
      const available = await profileRepository.isUsernameAvailable(data.username);
      if (!available) {
        // Check if it's the user's own current username
        const currentProfile = await profileRepository.findById(userId);
        if (!currentProfile || currentProfile.username.toLowerCase() !== data.username.toLowerCase()) {
          throw new AppError(409, 'USERNAME_TAKEN', 'That username is already in use.');
        }
      }
    }

    const updated = await profileRepository.updateProfile(userId, data);
    if (!updated) {
      throw new AppError(404, 'PROFILE_NOT_FOUND', 'Profile not found.');
    }

    return updated;
  },

  /**
   * Check username availability. UX pre-check only — the real enforcement
   * is the DB unique constraint hit during PUT /profiles/me.
   */
  async checkUsername(username: string): Promise<boolean> {
    return profileRepository.isUsernameAvailable(username);
  },

  /**
   * Soft-delete the user's account. Anonymizes PII immediately.
   * In a future phase, a BullMQ job will hard-delete after 30 days.
   */
  async deleteAccount(userId: string): Promise<void> {
    await profileRepository.softDelete(userId);
  },

  /**
   * Generate a signed upload URL for the user's avatar.
   * Also deletes the user's old avatar from storage if it exists,
   * and returns the pre-constructed public URL.
   */
  async generateAvatarUploadUrl(userId: string): Promise<{ signedUrl: string; path: string; publicUrl: string }> {
    // 1. Delete old avatar if present
    try {
      const profile = await profileRepository.findById(userId);
      if (profile?.avatar_url) {
        const marker = '/storage/v1/object/public/avatars/';
        const markerIndex = profile.avatar_url.indexOf(marker);
        if (markerIndex !== -1) {
          const oldPath = decodeURIComponent(profile.avatar_url.substring(markerIndex + marker.length));
          await supabaseAdmin.storage
            .from('avatars')
            .remove([oldPath]);
          console.log(`[profileService] Deleted old avatar in storage: ${oldPath}`);
        }
      }
    } catch (e) {
      console.error('[profileService] Failed to delete old avatar:', e);
    }

    // 2. Generate signed upload URL
    const path = `${userId}/avatar-${Date.now()}`;

    const { data, error } = await supabaseAdmin.storage
      .from('avatars')
      .createSignedUploadUrl(path);

    if (error || !data) {
      throw new AppError(500, 'INTERNAL_ERROR', 'Failed to generate upload URL.');
    }

    const { data: publicUrlData } = supabaseAdmin.storage
      .from('avatars')
      .getPublicUrl(path);

    return {
      signedUrl: data.signedUrl,
      path: data.path,
      publicUrl: publicUrlData.publicUrl,
    };
  },

  /**
   * Search profiles matching a query.
   */
  async searchProfiles(query: string, limit = 25): Promise<ProfileRow[]> {
    return profileRepository.searchProfiles(query, limit);
  },
};
