import 'package:cloud_firestore/cloud_firestore.dart';

class PassportStamp {
  const PassportStamp({
    required this.id,
    required this.attractionId,
    required this.attractionName,
    required this.imageName,
    required this.stampImageUrl,
    required this.collectedAt,
    required this.status,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String attractionId;
  final String attractionName;
  final String imageName;
  final String stampImageUrl;
  final DateTime collectedAt;
  final String status;
  final double? latitude;
  final double? longitude;

  factory PassportStamp.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? <String, dynamic>{};
    final timestamp = data['collectedAt'];

    return PassportStamp(
      id: document.id,
      attractionId: data['attractionId']?.toString() ?? '',
      attractionName: data['attractionName']?.toString() ?? 'Unknown attraction',
      imageName: data['imageName']?.toString() ?? '',
      stampImageUrl: data['stampImageUrl']?.toString() ?? '',
      collectedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      status: data['status']?.toString() ?? 'collected',
    );
  }

  PassportStamp withAttraction({
    required String name,
    required double latitude,
    required double longitude,
  }) {
    return PassportStamp(
      id: id,
      attractionId: attractionId,
      attractionName: name,
      imageName: imageName,
      stampImageUrl: stampImageUrl,
      collectedAt: collectedAt,
      status: status,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
