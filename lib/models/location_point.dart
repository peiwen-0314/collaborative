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
