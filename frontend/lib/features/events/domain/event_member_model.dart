enum RosterTeam { unassigned, teamA, teamB }

class EventMemberModel {
  final String id;
  final String eventId;
  final String? profileId;
  final String? guestName;
  final RosterTeam team;
  final bool isOfficial;
  final String addedBy;
  final DateTime joinedAt;
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  EventMemberModel({
    required this.id,
    required this.eventId,
    this.profileId,
    this.guestName,
    required this.team,
    required this.isOfficial,
    required this.addedBy,
    required this.joinedAt,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory EventMemberModel.fromJson(Map<String, dynamic> json) {
    RosterTeam team = RosterTeam.unassigned;
    final teamStr = json['team'] as String?;
    if (teamStr == 'team_a') {
      team = RosterTeam.teamA;
    } else if (teamStr == 'team_b') {
      team = RosterTeam.teamB;
    }

    return EventMemberModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      profileId: json['profile_id'] as String?,
      guestName: json['guest_name'] as String?,
      team: team,
      isOfficial: json['is_official'] as bool? ?? false,
      addedBy: json['added_by'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    String teamStr = 'unassigned';
    if (team == RosterTeam.teamA) {
      teamStr = 'team_a';
    } else if (team == RosterTeam.teamB) {
      teamStr = 'team_b';
    }

    return {
      'id': id,
      'event_id': eventId,
      'profile_id': profileId,
      'guest_name': guestName,
      'team': teamStr,
      'is_official': isOfficial,
      'added_by': addedBy,
      'joined_at': joinedAt.toIso8601String(),
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }
}
