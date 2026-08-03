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
    };
  }
}
