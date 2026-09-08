import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/attraction_detection_result.dart';
import '../models/heritage_attraction.dart';
import 'heritage_firestore_service.dart';

class AttractionDetectionService {
  AttractionDetectionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    HeritageFirestoreService? heritageService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _heritageService = heritageService ?? HeritageFirestoreService();

  static const double arrivalRadiusMetres = 150;
  static const int pointsReward = 500;
  static const int xpReward = 200;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final HeritageFirestoreService _heritageService;
  final Set<String> _processingAttractions = <String>{};

  Future<Stream<AttractionDetectionResult>> start() async {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Please turn on Location Services.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for auto-detection.');
    }

    final attractions = await _heritageService.getAttractions();
    final controller = StreamController<AttractionDetectionResult>();
    late final StreamSubscription<Position> positionSubscription;

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
          (position) => _checkPosition(
        userId: user.uid,
        position: position,
        attractions: attractions,
        controller: controller,
      ),
      onError: controller.addError,
    );

    controller.onCancel = positionSubscription.cancel;
    return controller.stream;
  }

  Future<void> _checkPosition({
    required String userId,
    required Position position,
    required List<HeritageAttraction> attractions,
    required StreamController<AttractionDetectionResult> controller,
  }) async {
    for (final attraction in attractions) {
      if (attraction.latitude == 0 || attraction.longitude == 0) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        attraction.latitude,
        attraction.longitude,
      );

      print(
        'DETECTION: ${attraction.name} | '
            '${distance.toStringAsFixed(1)} metres',
      );

      if (distance > arrivalRadiusMetres ||
          _processingAttractions.contains(attraction.id)) {
        continue;
      }

      _processingAttractions.add(attraction.id);
      try {
        final collected = await _collectStamp(
          userId: userId,
          attraction: attraction,
        );
        if (collected && !controller.isClosed) {
          controller.add(
            AttractionDetectionResult(
              attraction: attraction,
              distanceMetres: distance,
              pointsAwarded: pointsReward,
              xpAwarded: xpReward,
            ),
          );
        }
      } finally {
        _processingAttractions.remove(attraction.id);
      }
    }
  }

  Future<bool> _collectStamp({
    required String userId,
    required HeritageAttraction attraction,
  }) async {
    final summaryRef = _firestore.collection('gamification').doc(userId);
    final stampsRef = summaryRef.collection('stamps');
    final existingQuery = await stampsRef
        .where('attractionId', isEqualTo: attraction.id)
        .limit(1)
        .get();
    if (existingQuery.docs.isNotEmpty) return false;

    final stampRef = stampsRef.doc(attraction.id);
    final pointTransactionRef =
    summaryRef.collection('pointTransactions').doc();

    return _firestore.runTransaction((transaction) async {
      final existingStamp = await transaction.get(stampRef);
      if (existingStamp.exists) return false;

      final summary = await transaction.get(summaryRef);
      if (!summary.exists) {
        throw StateError('Gamification record not found for this account.');
      }

      final currentGrowth =
          (summary.data()?['treeGrowth'] as num?)?.toDouble() ?? 0.0;
      final updatedGrowth =
      (currentGrowth + (xpReward / 1000)).clamp(0.0, 1.0).toDouble();

      transaction.set(stampRef, {
        'attractionId': attraction.id,
        'attractionName': attraction.name,
        'imageName': '',
        'stampImageUrl': attraction.stampImageUrl,
        'imageUrl': attraction.imageUrl,
        'collectedAt': FieldValue.serverTimestamp(),
        'status': 'collected',
        'detectedAutomatically': true,
      });

      transaction.update(summaryRef, {
        'totalPoints': FieldValue.increment(pointsReward),
        'currentXp': FieldValue.increment(xpReward),
        'collectedStamps': FieldValue.increment(1),
        'treeGrowth': updatedGrowth,
      });
      transaction.set(pointTransactionRef, {
        'type': 'stamp',
        'title': 'Heritage Stamp Collected',
        'description': attraction.name,
        'points': pointsReward,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': attraction.id,
      });
      return true;
    });
  }
}
