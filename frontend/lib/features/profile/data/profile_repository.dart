import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:kickoff/core/network/api_client.dart';
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



  /// Upload an avatar image:
  /// 1. Get a signed upload URL and constructed public URL from backend (handles old avatar cleanup)
  /// 2. Upload the file directly to Supabase Storage using the signed URL
  /// 3. Return the public URL
  Future<String> uploadAvatar(File imageFile, {String? oldAvatarUrl}) async {
    // Step 1: Get signed upload URL and public URL from backend
    final urlResponse = await _apiClient.post('/api/profiles/me/avatar-upload-url', data: {});
    final signedUrl = urlResponse.data['signedUrl'] as String;
    final publicUrl = urlResponse.data['publicUrl'] as String;

    print('[ProfileRepository] Received signedUrl: $signedUrl');
    print('[ProfileRepository] Received publicUrl: $publicUrl');

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

  /// Search profiles matching a query.
  Future<List<ProfileModel>> searchProfiles(String query) async {
    final response = await _apiClient.get(
      '/api/profiles',
      queryParameters: {'query': query},
    );
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((item) => ProfileModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Check if current user is following target user.
  Future<bool> isFollowing(String targetUserId) async {
    final response = await _apiClient.get('/api/profiles/$targetUserId/is-following');
    return response.data['isFollowing'] as bool;
  }
}
