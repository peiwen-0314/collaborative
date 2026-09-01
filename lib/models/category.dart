import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String status;
  final int attractionCount;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.attractionCount,
    required this.createdAt,
  });

  // ============================================================
  // FIRESTORE -> MODEL
  // ============================================================

  factory CategoryModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data()!;

    return CategoryModel(
      id: document.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'Active',
      attractionCount: data['attractionCount'] ?? 0,
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  // ============================================================
  // MODEL -> FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'status': status,
      'attractionCount': attractionCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? status,
    int? attractionCount,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description:
      description ?? this.description,
      status: status ?? this.status,
      attractionCount:
      attractionCount ?? this.attractionCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}