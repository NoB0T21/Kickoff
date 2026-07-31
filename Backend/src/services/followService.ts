import { followRepository } from '../repositories/followRepository.js';
import { profileRepository } from '../repositories/profileRepository.js';
import { AppError } from '../middleware/errorHandler.js';

export const followService = {
  /**
   * Follow a user. Validates self-follow and duplicate follow.
   */
  async followUser(followerId: string, followingId: string): Promise<void> {
    // Defense-in-depth: reject self-follow at the service level too
    if (followerId === followingId) {
      throw new AppError(400, 'SELF_FOLLOW', 'You cannot follow yourself.');
    }

    // Check that the target profile exists
    const targetProfile = await profileRepository.findById(followingId);
    if (!targetProfile) {
      throw new AppError(404, 'PROFILE_NOT_FOUND', 'The user you are trying to follow does not exist.');
    }

    // Check if already following
    const alreadyFollowing = await followRepository.isFollowing(followerId, followingId);
    if (alreadyFollowing) {
      throw new AppError(409, 'ALREADY_FOLLOWING', 'You are already following this user.');
    }

    await followRepository.follow(followerId, followingId);
  },

  /**
   * Unfollow a user.
   */
  async unfollowUser(followerId: string, followingId: string): Promise<void> {
    const removed = await followRepository.unfollow(followerId, followingId);
    if (!removed) {
      throw new AppError(404, 'NOT_FOLLOWING', 'You are not following this user.');
    }
  },

  /**
   * Get paginated followers for a profile.
   */
  async getFollowers(profileId: string, cursor?: string, limit?: number) {
    return followRepository.getFollowers(profileId, cursor, limit);
  },

  /**
   * Get paginated following list for a profile.
   */
  async getFollowing(profileId: string, cursor?: string, limit?: number) {
    return followRepository.getFollowing(profileId, cursor, limit);
  },
};
