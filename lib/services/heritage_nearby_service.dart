import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

typedef NearbyHeritageCallback = Future<void> Function(
    NearbyHeritageResult result,
    );

class HeritageNearbyService {
  HeritageNearbyService({
    HeritageFirestoreService? firestoreService,
  }) : _firestoreService =
      firestoreService ?? HeritageFirestoreService();

  static const double defaultRadiusMeters = 1000;

  final HeritageFirestoreService _firestoreService;

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _positionSubscription;

  bool _notificationsInitialized = false;
  bool _processingLocation = false;

  List<HeritageAttraction> _cachedAttractions =
  const <HeritageAttraction>[];

  // ============================================================
  // NOTIFICATION INITIALIZATION
  // ============================================================

  Future<void> initializeNotifications() async {
    if (_notificationsInitialized) {
      return;
    }

    const android =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: android,
        iOS: ios,
      ),
    );

    final androidImplementation =
    _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation
        ?.requestNotificationsPermission();

    final iosImplementation =
    _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _notificationsInitialized = true;
  }

  // ============================================================
  // LOCATION PERMISSION
  // ============================================================

  Future<void> _ensureLocationPermission() async {
    final enabled =
    await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception(
        'Location service is turned off.',
      );
    }

    var permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
            'Enable it in Settings.',
      );
    }
  }

  Future<Position> currentPosition() async {
    await _ensureLocationPermission();

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // ============================================================
  // MANUAL NEARBY CHECK
  // Used by nearby_heritage_page.dart
  // ============================================================

  Future<List<NearbyHeritageResult>> findNearby({
    double radiusMeters = defaultRadiusMeters,
  }) async {
    final position = await currentPosition();

    final attractions =
    await _firestoreService.getAttractions();

    return _calculateNearby(
      position: position,
      attractions: attractions,
      radiusMeters: radiusMeters,
    );
  }

  // ============================================================
  // AUTOMATIC NEARBY MONITORING
  // ============================================================

  Future<void> startAutomaticMonitoring({
    double radiusMeters = defaultRadiusMeters,
    int distanceFilterMeters = 50,
    Duration notificationCooldown =
    const Duration(hours: 6),
    NearbyHeritageCallback? onNearbyDetected,
  }) async {
    // Do not create a second GPS stream.
    if (_positionSubscription != null) {
      return;
    }

    await initializeNotifications();
    await _ensureLocationPermission();

    // Load all heritage attractions from Firestore once.
    _cachedAttractions =
    await _firestoreService.getAttractions();

    // Check the current position immediately.
    final initialPosition =
    await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    await _processAutomaticLocation(
      initialPosition,
      radiusMeters: radiusMeters,
      notificationCooldown:
      notificationCooldown,
      onNearbyDetected: onNearbyDetected,
    );

    // Continue checking as the user moves.
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
              (position) async {
            await _processAutomaticLocation(
              position,
              radiusMeters: radiusMeters,
              notificationCooldown:
              notificationCooldown,
              onNearbyDetected:
              onNearbyDetected,
            );
          },
          onError: (Object error) {
            // Keep background stream errors silent.
            // The manual nearby page can still show
            // location errors to the user.
          },
        );
  }

  Future<void> stopAutomaticMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _processAutomaticLocation(
      Position position, {
        required double radiusMeters,
        required Duration notificationCooldown,
        NearbyHeritageCallback? onNearbyDetected,
      }) async {
    if (_processingLocation) {
      return;
    }

    _processingLocation = true;

    try {
      if (_cachedAttractions.isEmpty) {
        _cachedAttractions =
        await _firestoreService.getAttractions();
      }

      final nearby = _calculateNearby(
        position: position,
        attractions: _cachedAttractions,
        radiusMeters: radiusMeters,
      );

      if (nearby.isEmpty) {
        return;
      }

      // Nearby is already sorted nearest-first.
      // Notify only the nearest attraction that is
      // not currently inside its cooldown period.
      for (final result in nearby) {
        final canNotify =
        await _canNotifyAttraction(
          result.attraction.id,
          notificationCooldown,
        );

        if (!canNotify) {
          continue;
        }

        await showNearbyNotification(result);

        await _saveNotificationTime(
          result.attraction.id,
        );

        // Tell the CulturalHeritagePage to show
        // the image popup while the app is open.
        if (onNearbyDetected != null) {
          await onNearbyDetected(result);
        }

        break;
      }
    } finally {
      _processingLocation = false;
    }
  }

  // ============================================================
  // DISTANCE CALCULATION
  // ============================================================

  List<NearbyHeritageResult> _calculateNearby({
    required Position position,
    required List<HeritageAttraction> attractions,
    required double radiusMeters,
  }) {
    final results = <NearbyHeritageResult>[];

    for (final attraction in attractions) {
      final distance =
      Geolocator.distanceBetween(
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

    results.sort(
          (a, b) => a.distanceMeters
          .compareTo(b.distanceMeters),
    );

    return results;
  }

  // ============================================================
  // DUPLICATE NOTIFICATION PREVENTION
  // ============================================================

  String _notificationTimeKey(
      String attractionId,
      ) {
    return 'heritage_nearby_last_$attractionId';
  }

  Future<bool> _canNotifyAttraction(
      String attractionId,
      Duration cooldown,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    final raw = prefs.getString(
      _notificationTimeKey(attractionId),
    );

    if (raw == null) {
      return true;
    }

    final lastTime =
    DateTime.tryParse(raw);

    if (lastTime == null) {
      return true;
    }

    return DateTime.now()
        .difference(lastTime) >=
        cooldown;
  }

  Future<void> _saveNotificationTime(
      String attractionId,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      _notificationTimeKey(attractionId),
      DateTime.now().toIso8601String(),
    );
  }

  // ============================================================
  // SHOW PHONE NOTIFICATION
  // ============================================================

  Future<void> showNearbyNotification(
      NearbyHeritageResult result,
      ) async {
    await initializeNotifications();

    const androidDetails =
    AndroidNotificationDetails(
      'heritage_nearby',
      'Nearby Heritage',
      channelDescription:
      'Alerts for nearby cultural and heritage places',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails =
    DarwinNotificationDetails();

    final notificationId =
    result.attraction.id.hashCode &
    0x7fffffff;

    final distance =
    result.distanceMeters.round();

    await _notifications.show(
      notificationId,
      'Heritage attraction nearby',
      '${result.attraction.name} is $distance m away. '
          'Discover its history and culture nearby.',
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: result.attraction.id,
    );
  }
}
