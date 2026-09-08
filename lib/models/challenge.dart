import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeDefinition {
  const ChallengeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.challengeType,
    required this.targetValue,
    required this.rewardPoints,
    required this.rewardXp,
    required this.imageName,
    required this.imageUrl,
    required this.iconType,
    required this.trackingSource,
    required this.requiredAttractionIds,
    required this.isActive,
    required this.displayOrder,
    required this.unit,
    required this.badgeName,
    required this.badgeDescription,
    required this.badgeImageUrl,
    this.startAt,
    this.endAt,
  });

  final String id;
  final String title;
  final String description;
  final String challengeType;
  final double targetValue;
  final int rewardPoints;
  final int rewardXp;
  final String imageName;
  final String imageUrl;
  final String iconType;
  final String trackingSource;
  final List<String> requiredAttractionIds;
  final bool isActive;
  final int displayOrder;
  final String unit;
  final DateTime? startAt;
  final DateTime? endAt;
  final String badgeName;
  final String badgeDescription;
  final String badgeImageUrl;

  factory ChallengeDefinition.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? <String, dynamic>{};
    final requiredIds = data['requiredAttractionIds'];
    return ChallengeDefinition(
      id: document.id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      challengeType: data['challengeType']?.toString() ?? '',
      targetValue: (data['targetValue'] as num?)?.toDouble() ?? 1,
      rewardPoints: (data['rewardPoints'] as num?)?.toInt() ?? 0,
      rewardXp: (data['rewardXp'] as num?)?.toInt() ?? 0,
      imageName: data['imageName']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      iconType: data['iconType']?.toString() ?? 'heritage',
      trackingSource: data['trackingSource']?.toString() ?? 'location',
      requiredAttractionIds: requiredIds is List
          ? requiredIds.map((value) => value.toString()).toList()
          : const [],
      isActive: data['isActive'] == true,
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 999,
      unit: data['unit']?.toString() ?? '',
      badgeName: data['badgeName']?.toString() ?? '',
      badgeDescription: data['badgeDescription']?.toString() ?? '',
      badgeImageUrl: data['badgeImageUrl']?.toString() ?? '',
      startAt: data['startAt'] is Timestamp
          ? (data['startAt'] as Timestamp).toDate()
          : null,
      endAt: data['endAt'] is Timestamp
          ? (data['endAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class UserChallenge {
  const UserChallenge({
    required this.definition,
    required this.currentValue,
    required this.isCompleted,
  });

  final ChallengeDefinition definition;
  final double currentValue;
  final bool isCompleted;

  double get progress => definition.targetValue <= 0
      ? 0
      : (currentValue / definition.targetValue).clamp(0.0, 1.0).toDouble();
}
