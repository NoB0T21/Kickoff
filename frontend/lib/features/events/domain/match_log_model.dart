import 'event_member_model.dart';

class MatchLogModel {
  final String id;
  final String eventId;
  final RosterTeam team;
  final String? scorerMemberId;
  final int? minute;
  final double? overNumber;
  final String logType;
  final int runs;
  final String? extraType;
  final String? dismissalType;
  final String message;
  final DateTime createdAt;
  final String? playerName;

  MatchLogModel({
    required this.id,
    required this.eventId,
    required this.team,
    this.scorerMemberId,
    this.minute,
    this.overNumber,
    required this.logType,
    required this.runs,
    this.extraType,
    this.dismissalType,
    required this.message,
    required this.createdAt,
    this.playerName,
  });

  factory MatchLogModel.fromJson(Map<String, dynamic> json) {
    RosterTeam team = RosterTeam.unassigned;
    final teamStr = json['team'] as String?;
    if (teamStr == 'A' || teamStr == 'team_a') {
      team = RosterTeam.teamA;
    } else if (teamStr == 'B' || teamStr == 'team_b') {
      team = RosterTeam.teamB;
    }

    return MatchLogModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      team: team,
      scorerMemberId: json['scorer_member_id'] as String?,
      minute: json['minute'] as int?,
      overNumber: (json['over_number'] as num?)?.toDouble(),
      logType: json['log_type'] as String,
      runs: json['runs'] as int? ?? 0,
      extraType: json['extra_type'] as String?,
      dismissalType: json['dismissal_type'] as String?,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      playerName: json['player_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    String teamStr = 'unassigned';
    if (team == RosterTeam.teamA) teamStr = 'team_a';
    if (team == RosterTeam.teamB) teamStr = 'team_b';

    return {
      'id': id,
      'event_id': eventId,
      'team': teamStr,
      'scorer_member_id': scorerMemberId,
      'minute': minute,
      'over_number': overNumber,
      'log_type': logType,
      'runs': runs,
      'extra_type': extraType,
      'dismissal_type': dismissalType,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'player_name': playerName,
    };
  }
}
