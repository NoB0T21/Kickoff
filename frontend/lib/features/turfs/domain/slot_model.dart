enum SlotStatus { available, locked, booked }

class SlotModel {
  final String id;
  final String turfId;
  final String slotDate;
  final int startHour;
  final int endHour;
  final double price;
  final SlotStatus status;
  final String? lockedBy;
  final DateTime? lockedUntil;

  SlotModel({
    required this.id,
    required this.turfId,
    required this.slotDate,
    required this.startHour,
    required this.endHour,
    required this.price,
    required this.status,
    this.lockedBy,
    this.lockedUntil,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    SlotStatus status = SlotStatus.available;
    if (json['status'] == 'locked') {
      status = SlotStatus.locked;
    } else if (json['status'] == 'booked') {
      status = SlotStatus.booked;
    }

    return SlotModel(
      id: json['id'] as String,
      turfId: json['turf_id'] as String,
      slotDate: json['slot_date'] as String,
      startHour: json['start_hour'] as int,
      endHour: json['end_hour'] as int,
      price: double.parse(json['price'].toString()),
      status: status,
      lockedBy: json['locked_by'] as String?,
      lockedUntil: json['locked_until'] != null ? DateTime.parse(json['locked_until'] as String) : null,
    );
  }
}
