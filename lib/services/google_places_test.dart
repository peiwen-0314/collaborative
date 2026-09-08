import 'google_places_service.dart';

Future<void> testGooglePlaces() async {
  final service = GooglePlacesService();

  final places = await service.searchPlaces(
    'Petronas Twin Towers Kuala Lumpur',
  );

  for (final place in places) {
    print('============================');
    print('Place ID: ${place.placeId}');
    print('Name: ${place.name}');
    print('Address: ${place.address}');
    print('Latitude: ${place.latitude}');
    print('Longitude: ${place.longitude}');
  }
}