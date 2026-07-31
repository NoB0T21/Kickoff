/// Profile data model matching the backend response shape.
class ProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String skillLevel;
  final String primarySport;
  final int totalPoints;
  final int followersCount;
  final int followingCount;
  final bool hasCompletedOnboarding;
  final Map<String, dynamic> avatarVariants;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.skillLevel,
    required this.primarySport,
    required this.totalPoints,
    required this.followersCount,
    required this.followingCount,
    required this.hasCompletedOnboarding,
    required this.avatarVariants,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      skillLevel: json['skill_level'] as String,
      primarySport: json['primary_sport'] as String,
      totalPoints: json['total_points'] as int? ?? 0,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      hasCompletedOnboarding: json['has_completed_onboarding'] as bool? ?? false,
      avatarVariants: (json['avatar_variants'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'skill_level': skillLevel,
      'primary_sport': primarySport,
      'total_points': totalPoints,
      'followers_count': followersCount,
      'following_count': followingCount,
      'has_completed_onboarding': hasCompletedOnboarding,
      'avatar_variants': avatarVariants,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? skillLevel,
    String? primarySport,
    bool? hasCompletedOnboarding,
  }) {
    return ProfileModel(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      skillLevel: skillLevel ?? this.skillLevel,
      primarySport: primarySport ?? this.primarySport,
      totalPoints: totalPoints,
      followersCount: followersCount,
      followingCount: followingCount,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      avatarVariants: avatarVariants,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
