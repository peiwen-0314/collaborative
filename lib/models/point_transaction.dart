import 'package:cloud_firestore/cloud_firestore.dart';

class PointTransaction {
  const PointTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.points,
    required this.createdAt,
    required this.referenceId,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final int points;
  final DateTime createdAt;
  final String referenceId;

  factory PointTransaction.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];

    return PointTransaction(
      id: doc.id,
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Points',
      description: data['description']?.toString() ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      createdAt:
      timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      referenceId: data['referenceId']?.toString() ?? '',
    );
  }

  bool get isPositive => points >= 0;
}