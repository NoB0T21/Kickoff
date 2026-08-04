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

  // Cricket statistics fields
  final int battingRuns;
  final int ballsFaced;
  final bool isOut;
  final int bowlerRuns;
  final int bowlerWickets;
  final int bowlerBalls;
  final int bowlerWides;
  final int bowlerNoballs;
  final int bowlerDots;
  final int bowlerFours;
  final int bowlerSixes;

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
    this.battingRuns = 0,
    this.ballsFaced = 0,
    this.isOut = false,
    this.bowlerRuns = 0,
    this.bowlerWickets = 0,
    this.bowlerBalls = 0,
    this.bowlerWides = 0,
    this.bowlerNoballs = 0,
    this.bowlerDots = 0,
    this.bowlerFours = 0,
    this.bowlerSixes = 0,
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
      battingRuns: json['batting_runs'] as int? ?? 0,
      ballsFaced: json['balls_faced'] as int? ?? 0,
      isOut: json['is_out'] as bool? ?? false,
      bowlerRuns: json['bowler_runs'] as int? ?? 0,
      bowlerWickets: json['bowler_wickets'] as int? ?? 0,
      bowlerBalls: json['bowler_balls'] as int? ?? 0,
      bowlerWides: json['bowler_wides'] as int? ?? 0,
      bowlerNoballs: json['bowler_noballs'] as int? ?? 0,
      bowlerDots: json['bowler_dots'] as int? ?? 0,
      bowlerFours: json['bowler_fours'] as int? ?? 0,
      bowlerSixes: json['bowler_sixes'] as int? ?? 0,
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
      'batting_runs': battingRuns,
      'balls_faced': ballsFaced,
      'is_out': isOut,
      'bowler_runs': bowlerRuns,
      'bowler_wickets': bowlerWickets,
      'bowler_balls': bowlerBalls,
      'bowler_wides': bowlerWides,
      'bowler_noballs': bowlerNoballs,
      'bowler_dots': bowlerDots,
      'bowler_fours': bowlerFours,
      'bowler_sixes': bowlerSixes,
    };
  }
}
