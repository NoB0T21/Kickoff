class TurfModel {
  final String id;
  final String? ownerId;
  final String name;
  final String locationName;
  final double latitude;
  final double longitude;
  final String? description;
  final List<String> sports;
  final List<String> imageUrls;
  final double hourlyRate;
  final int openHour;
  final int closeHour;
  final double? distanceKm;

  TurfModel({
    required this.id,
    this.ownerId,
    required this.name,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    this.description,
    required this.sports,
    required this.imageUrls,
    required this.hourlyRate,
    required this.openHour,
    required this.closeHour,
    this.distanceKm,
  });

  factory TurfModel.fromJson(Map<String, dynamic> json) {
    return TurfModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String?,
      name: json['name'] as String,
      locationName: json['location_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String?,
      sports: List<String>.from(json['sports'] ?? []),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      hourlyRate: double.parse(json['hourly_rate'].toString()),
      openHour: json['open_hour'] as int,
      closeHour: json['close_hour'] as int,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
    );
  }
}
