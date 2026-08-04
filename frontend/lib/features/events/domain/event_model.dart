enum EventPrivacy { public, private }

enum EventStatus { scheduled, live, completed, cancelled }

class EventModel {
  final String id;
  final String bookingId;
  final String hostId;
  final String turfId;
  final String title;
  final String? description;
  final String sport;
  final EventPrivacy privacy;
  final int capacity;
  final EventStatus status;
  final String? inviteToken;
  final String? qrCheckInCode;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? checkedInAt;
  final DateTime createdAt;
  final String? turfName;
  
  // Live score fields
  final int teamAScore;
  final int teamBScore;
  final int teamAWickets;
  final int teamBWickets;
  final int teamABalls;
  final int teamBBalls;
  final String currentBatting; // 'team_a' or 'team_b' or 'unassigned'

  // Cricket live state fields
  final String? strikerId;
  final String? nonStrikerId;
  final String? currentBowlerId;
  final String? tossWinnerTeam; // 'team_a' or 'team_b' or 'unassigned'
  final String? tossDecision; // 'bat' or 'bowl'
  final int maxOvers;

  EventModel({
    required this.id,
    required this.bookingId,
    required this.hostId,
    required this.turfId,
    required this.title,
    this.description,
    required this.sport,
    required this.privacy,
    required this.capacity,
    required this.status,
    this.inviteToken,
    this.qrCheckInCode,
    required this.startsAt,
    required this.endsAt,
    this.checkedInAt,
    required this.createdAt,
    this.turfName,
    this.teamAScore = 0,
    this.teamBScore = 0,
    this.teamAWickets = 0,
    this.teamBWickets = 0,
    this.teamABalls = 0,
    this.teamBBalls = 0,
    this.currentBatting = 'team_a',
    this.strikerId,
    this.nonStrikerId,
    this.currentBowlerId,
    this.tossWinnerTeam,
    this.tossDecision,
    this.maxOvers = 10,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    EventPrivacy privacy = EventPrivacy.public;
    if (json['privacy'] == 'private') {
      privacy = EventPrivacy.private;
    }

    EventStatus status = EventStatus.scheduled;
    final statusStr = json['status'] as String?;
    if (statusStr == 'live') {
      status = EventStatus.live;
    } else if (statusStr == 'completed') {
      status = EventStatus.completed;
    } else if (statusStr == 'cancelled') {
      status = EventStatus.cancelled;
    }

    return EventModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      hostId: json['host_id'] as String,
      turfId: json['turf_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      sport: json['sport'] as String,
      privacy: privacy,
      capacity: json['capacity'] as int,
      status: status,
      inviteToken: json['invite_token'] as String?,
      qrCheckInCode: json['qr_check_in_code'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      checkedInAt: json['checked_in_at'] != null ? DateTime.parse(json['checked_in_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      turfName: json['turf_name'] as String?,
      teamAScore: json['team_a_score'] as int? ?? 0,
      teamBScore: json['team_b_score'] as int? ?? 0,
      teamAWickets: json['team_a_wickets'] as int? ?? 0,
      teamBWickets: json['team_b_wickets'] as int? ?? 0,
      teamABalls: json['team_a_balls'] as int? ?? 0,
      teamBBalls: json['team_b_balls'] as int? ?? 0,
      currentBatting: json['current_batting'] as String? ?? 'team_a',
      strikerId: json['striker_id'] as String?,
      nonStrikerId: json['non_striker_id'] as String?,
      currentBowlerId: json['current_bowler_id'] as String?,
      tossWinnerTeam: json['toss_winner_team'] as String?,
      tossDecision: json['toss_decision'] as String?,
      maxOvers: json['max_overs'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'host_id': hostId,
      'turf_id': turfId,
      'title': title,
      'description': description,
      'sport': sport,
      'privacy': privacy.name,
      'capacity': capacity,
      'status': status.name,
      'invite_token': inviteToken,
      'qr_check_in_code': qrCheckInCode,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'turf_name': turfName,
      'team_a_score': teamAScore,
      'team_b_score': teamBScore,
      'team_a_wickets': teamAWickets,
      'team_b_wickets': teamBWickets,
      'team_a_balls': teamABalls,
      'team_b_balls': teamBBalls,
      'current_batting': currentBatting,
      'striker_id': strikerId,
      'non_striker_id': nonStrikerId,
      'current_bowler_id': currentBowlerId,
      'toss_winner_team': tossWinnerTeam,
      'toss_decision': tossDecision,
      'max_overs': maxOvers,
    };
  }
}
