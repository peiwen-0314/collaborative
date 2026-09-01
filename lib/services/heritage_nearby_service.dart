import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../models/heritage_attraction.dart';
import 'heritage_firestore_service.dart';

class NearbyHeritageResult {
  const NearbyHeritageResult({
    required this.attraction,
    required this.distanceMeters,
  });

  final HeritageAttraction attraction;
  final double distanceMeters;
}

class HeritageNearbyService {
  HeritageNearbyService({HeritageFirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? HeritageFirestoreService();

  final HeritageFirestoreService _firestoreService;
  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  Future<void> initializeNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidImplementation =
    _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  Future<Position> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location service is turned off.');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it in Settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<List<NearbyHeritageResult>> findNearby({
    double radiusMeters = 1000,
  }) async {
    final position = await currentPosition();
    final attractions = await _firestoreService.getAttractions();
    final results = <NearbyHeritageResult>[];

    for (final attraction in attractions) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        attraction.latitude,
        attraction.longitude,
      );
      if (distance <= radiusMeters) {
        results.add(
          NearbyHeritageResult(
            attraction: attraction,
            distanceMeters: distance,
          ),
        );
      }
    }

    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  Future<void> showNearbyNotification(NearbyHeritageResult result) async {
    const androidDetails = AndroidNotificationDetails(
      'heritage_nearby',
      'Nearby Heritage',
      channelDescription: 'Alerts for nearby cultural and heritage places',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      2001,
      'Heritage attraction nearby',
      '${result.attraction.name} is ${result.distanceMeters.round()} m away.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
