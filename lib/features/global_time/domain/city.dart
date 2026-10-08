import 'package:latlong2/latlong.dart';

/// A city used by RAD Global Time.
class City {
  const City({
    required this.id,
    required this.nameEn,
    required this.nameFa,
    required this.countryCode,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    this.flagEmoji,
  });

  final String id;
  final String nameEn;
  final String nameFa;
  final String countryCode;
  final String timezone; // IANA id e.g. Asia/Tehran
  final double latitude;
  final double longitude;
  final String? flagEmoji;

  LatLng get latLng => LatLng(latitude, longitude);

  String localizedName(String languageCode) =>
      languageCode == 'fa' ? nameFa : nameEn;

  City copyWith({
    String? id,
    String? nameEn,
    String? nameFa,
    String? countryCode,
    String? timezone,
    double? latitude,
    double? longitude,
    String? flagEmoji,
  }) {
    return City(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameFa: nameFa ?? this.nameFa,
      countryCode: countryCode ?? this.countryCode,
      timezone: timezone ?? this.timezone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      flagEmoji: flagEmoji ?? this.flagEmoji,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameFa': nameFa,
        'countryCode': countryCode,
        'timezone': timezone,
        'latitude': latitude,
        'longitude': longitude,
        'flagEmoji': flagEmoji,
      };

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as String,
        nameEn: json['nameEn'] as String,
        nameFa: json['nameFa'] as String,
        countryCode: json['countryCode'] as String,
        timezone: json['timezone'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        flagEmoji: json['flagEmoji'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
