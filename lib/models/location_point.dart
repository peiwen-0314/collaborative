import 'dart:math';

/// A named place with coordinates, used for the From/To fields of a search
/// and for the HERE routing API calls.
class LocationPoint {
  const LocationPoint({required this.name, required this.lat, required this.lng});

  /// Human readable label, e.g. "Rawang, Kuala Lumpur".
  final String name;
  final double lat;
  final double lng;

  /// "lat,lng" string in the format the HERE API expects.
  String get coordinateString => '$lat,$lng';

  /// Great-circle (haversine) distance in kilometres to [other] - the one
  /// implementation every straight-line-distance need in this module
  /// shares (MockTransportRepository's own distance split, SavedListPage
  /// sorting saved trips by real proximity to the person's current
  /// location, etc.), so they can't quietly drift out of sync with each
  /// other.
  double distanceKm(LocationPoint other) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(other.lat - lat);
    final dLng = _degToRad(other.lng - lng);
    final lat1 = _degToRad(lat);
    final lat2 = _degToRad(other.lat);

    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * pi / 180;

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lng': lng};

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is LocationPoint &&
      other.name == name &&
      other.lat == lat &&
      other.lng == lng;

  @override
  int get hashCode => Object.hash(name, lat, lng);

  @override
  String toString() => name;
}
