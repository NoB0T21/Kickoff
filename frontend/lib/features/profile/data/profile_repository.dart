import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import 'package:kickoff/core/network/api_client.dart';
import 'package:kickoff/core/constants/constants.dart';
import 'package:kickoff/features/profile/domain/profile_model.dart';

/// Profile repository — all data operations go through the backend API.
/// Avatar upload uses Supabase Storage directly (via signed URL from backend).
class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get the authenticated user's own profile.
  Future<ProfileModel> getMyProfile() async {
    final response = await _apiClient.get('/api/profiles/me');
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get a profile by ID.
  Future<ProfileModel> getProfile(String id) async {
    final response = await _apiClient.get('/api/profiles/$id');
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update the authenticated user's profile.
  Future<ProfileModel> updateProfile({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? primarySport,
    String? skillLevel,
  }) async {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (fullName != null) data['full_name'] = fullName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (primarySport != null) data['primary_sport'] = primarySport;
    if (skillLevel != null) data['skill_level'] = skillLevel;

    final response = await _apiClient.put('/api/profiles/me', data: data);
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Check username availability (UX pre-check — debounce on the UI side).
  Future<bool> checkUsername(String username) async {
    final response = await _apiClient.get(
      '/api/profiles/username-check',
      queryParameters: {'username': username},
    );
    return response.data['available'] as bool;
  }

  /// Helper to extract storage path (e.g. "userId/avatar-timestamp") from a public URL.
  String? _extractStoragePath(String url) {
    const marker = '/storage/v1/object/public/avatars/';
    final markerIndex = url.indexOf(marker);
    if (markerIndex != -1) {
      return Uri.decodeComponent(url.substring(markerIndex + marker.length));
    }
    return null;
  }

  /// Upload an avatar image:
  /// 1. Delete the old avatar from storage if any
  /// 2. Get a signed upload URL from the backend
  /// 3. Upload the file directly to Supabase Storage
  /// 4. Return the public URL
  Future<String> uploadAvatar(File imageFile, {String? oldAvatarUrl}) async {
    // Delete old avatar if present
    if (oldAvatarUrl != null) {
      try {
        final oldPath = _extractStoragePath(oldAvatarUrl);
        if (oldPath != null) {
          await Supabase.instance.client.storage
              .from(AppConstants.avatarsBucket)
              .remove([oldPath]);
          print('[ProfileRepository] Successfully deleted old avatar: $oldPath');
        }
      } catch (e, stackTrace) {
        print('[ProfileRepository] Failed to delete old avatar: $e\n$stackTrace');
      }
    }

    // Step 1: Get signed upload URL from backend
    final urlResponse = await _apiClient.post('/api/profiles/me/avatar-upload-url', data: {});
    final signedUrl = urlResponse.data['signedUrl'] as String;
    final storagePath = urlResponse.data['path'] as String;

    print('[ProfileRepository] Received signedUrl: $signedUrl');
    print('[ProfileRepository] Received storagePath: $storagePath');

    // Step 2: Upload directly to Supabase Storage using the signed URL
    final dio = Dio();

    // Map content type correctly (e.g. image/jpg is not accepted by bucket, must be image/jpeg)
    final extension = imageFile.path.split('.').last.toLowerCase();
    final contentType = (extension == 'jpg' || extension == 'jpeg')
        ? 'image/jpeg'
        : (extension == 'png' ? 'image/png' : 'image/webp');

    try {
      final bytes = await imageFile.readAsBytes();
      final contentLength = bytes.length;

      print('[ProfileRepository] Attempting raw binary upload to signed URL: $signedUrl');
      await dio.put(
        signedUrl,
        data: bytes,
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': contentLength.toString(),
          },
        ),
      );
      print('[ProfileRepository] Raw binary upload succeeded.');
    } catch (rawError) {
      print('[ProfileRepository] Raw binary upload failed: $rawError');
      if (rawError is DioException) {
        print('[ProfileRepository] Raw binary upload DioError type: ${rawError.type}');
        print('[ProfileRepository] Raw binary upload DioError message: ${rawError.message}');
        print('[ProfileRepository] Raw binary upload DioError error: ${rawError.error}');
        print('[ProfileRepository] Raw binary upload DioError response: ${rawError.response}');
      }
      print('[ProfileRepository] Retrying with multipart/form-data...');
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
            contentType: MediaType.parse(contentType),
          ),
        });

        await dio.put(
          signedUrl,
          data: formData,
        );
        print('[ProfileRepository] Multipart upload succeeded.');
      } on DioException catch (multipartError) {
        final responseBody = multipartError.response?.data;
        final statusCode = multipartError.response?.statusCode;
        print('[ProfileRepository] Multipart upload failed with status $statusCode: $responseBody');
        throw Exception(
            'Failed to upload image. Raw upload error: $rawError. Multipart upload error status $statusCode: $responseBody');
      } catch (e) {
        print('[ProfileRepository] Multipart upload failed: $e');
        throw Exception('Failed to upload image. Raw error: $rawError. Multipart error: $e');
      }
    }

    // Step 3: Construct the public URL
    final publicUrl = Supabase.instance.client.storage
        .from(AppConstants.avatarsBucket)
        .getPublicUrl(storagePath);

    return publicUrl;
  }

  /// Delete the authenticated user's account (soft-delete).
  Future<void> deleteAccount() async {
    await _apiClient.delete('/api/profiles/me');
  }

  /// Follow a user.
  Future<void> followUser(String userId) async {
    await _apiClient.post('/api/profiles/$userId/follow', data: {});
  }

  /// Unfollow a user.
  Future<void> unfollowUser(String userId) async {
    await _apiClient.post('/api/profiles/$userId/unfollow', data: {});
  }
}
