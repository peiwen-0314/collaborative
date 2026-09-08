import 'heritage_attraction.dart';

class AttractionDetectionResult {
  const AttractionDetectionResult({
    required this.attraction,
    required this.distanceMetres,
    required this.pointsAwarded,
    required this.xpAwarded,
  });

  final HeritageAttraction attraction;
  final double distanceMetres;
  final int pointsAwarded;
  final int xpAwarded;
}
