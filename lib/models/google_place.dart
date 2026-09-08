class GooglePlacePhoto {
  final String name;
  final List<String> authorAttributions;

  const GooglePlacePhoto({
    required this.name,
    this.authorAttributions = const [],
  });

  factory GooglePlacePhoto.fromJson(Map<String, dynamic> json) {
    final authors = <String>[];
    final raw = json['authorAttributions'];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final displayName = (item['displayName'] ?? '').toString().trim();
          if (displayName.isNotEmpty) authors.add(displayName);
        }
      }
    }

    return GooglePlacePhoto(
      name: (json['name'] ?? '').toString().trim(),
      authorAttributions: authors,
    );
  }
}

class GooglePlace {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  final String phoneNumber;
  final String websiteUrl;

  final String state;
  final String area;

  /// Example:
  /// {
  ///   'Monday': ['10:00-13:00', '14:00-18:00'],
  ///   'Tuesday': ['10:00-18:00'],
  ///   'Wednesday': [],
  /// }
  final Map<String, List<String>> openingHours;

  final List<GooglePlacePhoto> photos;

  const GooglePlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phoneNumber = '',
    this.websiteUrl = '',
    this.state = '',
    this.area = '',
    this.openingHours = const {},
    this.photos = const [],
  });

  factory GooglePlace.fromSearchJson(Map<String, dynamic> json) {
    final displayName =
        json['displayName'] as Map<String, dynamic>? ?? const {};

    final location =
        json['location'] as Map<String, dynamic>? ?? const {};

    return GooglePlace(
      placeId: (json['id'] ?? '').toString().trim(),
      name: (displayName['text'] ?? '').toString().trim(),
      address: (json['formattedAddress'] ?? '').toString().trim(),
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}
