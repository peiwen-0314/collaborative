import 'package:cloud_firestore/cloud_firestore.dart';

class AttractionModel {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String state;
  final String area;
  final String description;
  final bool isFreeEntry;

  final double malaysianAdultFee;
  final double malaysianChildFee;
  final double malaysianSeniorFee;
  final double nonMalaysianAdultFee;
  final double nonMalaysianChildFee;
  final double nonMalaysianSeniorFee;

  final String openingTime;
  final String closingTime;
  final String recommendedDuration;

  final String address;
  final String phoneNumber;
  final double latitude;
  final double longitude;

  final List<String> facilities;
  final List<String> highlights;
  final List<String> imageUrls;
  final String coverImageUrl;

  final String status;
  final DateTime createdAt;

  AttractionModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.state,
    required this.area,
    required this.description,
    required this.isFreeEntry,
    required this.malaysianAdultFee,
    required this.malaysianChildFee,
    required this.malaysianSeniorFee,
    required this.nonMalaysianAdultFee,
    required this.nonMalaysianChildFee,
    required this.nonMalaysianSeniorFee,
    required this.openingTime,
    required this.closingTime,
    required this.recommendedDuration,
    required this.address,
    required this.phoneNumber,
    this.latitude = 0,
    this.longitude = 0,
    required this.facilities,
    required this.highlights,
    required this.imageUrls,
    required this.coverImageUrl,
    required this.status,
    required this.createdAt,
  });

  factory AttractionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? <String, dynamic>{};

    double number(String key, {String? fallbackKey}) {
      dynamic value = data[key];

      if (value == null && fallbackKey != null) {
        value = data[fallbackKey];
      }

      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? 0;
      return 0;
    }

    List<String> stringList(String key) {
      final value = data[key];

      if (value is List) {
        return value
            .where((item) => item != null)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      return <String>[];
    }

    final loadedImageUrls = stringList('imageUrls');
    String loadedCoverImageUrl =
    (data['coverImageUrl'] ?? '').toString().trim();

    if (loadedCoverImageUrl.isEmpty && loadedImageUrls.isNotEmpty) {
      loadedCoverImageUrl = loadedImageUrls.first;
    }

    DateTime loadedCreatedAt = DateTime.now();
    final createdAtValue = data['createdAt'];

    if (createdAtValue is Timestamp) {
      loadedCreatedAt = createdAtValue.toDate();
    } else if (createdAtValue is DateTime) {
      loadedCreatedAt = createdAtValue;
    } else if (createdAtValue is String) {
      loadedCreatedAt =
          DateTime.tryParse(createdAtValue) ?? DateTime.now();
    }

    return AttractionModel(
      id: document.id,
      name: (data['name'] ?? '').toString().trim(),
      categoryId: (data['categoryId'] ?? '').toString().trim(),
      categoryName: (data['categoryName'] ?? '').toString().trim(),
      state: (data['state'] ?? '').toString().trim(),
      area: (data['area'] ?? '').toString().trim(),
      description: (data['description'] ?? '').toString().trim(),
      isFreeEntry: data['isFreeEntry'] == true,
      malaysianAdultFee:
      number('malaysianAdultFee', fallbackKey: 'adultFee'),
      malaysianChildFee:
      number('malaysianChildFee', fallbackKey: 'childFee'),
      malaysianSeniorFee: number('malaysianSeniorFee'),
      nonMalaysianAdultFee:
      number('nonMalaysianAdultFee', fallbackKey: 'adultFee'),
      nonMalaysianChildFee:
      number('nonMalaysianChildFee', fallbackKey: 'childFee'),
      nonMalaysianSeniorFee: number('nonMalaysianSeniorFee'),
      openingTime: (data['openingTime'] ?? '').toString().trim(),
      closingTime: (data['closingTime'] ?? '').toString().trim(),
      recommendedDuration:
      (data['recommendedDuration'] ?? '').toString().trim(),
      address: (data['address'] ?? '').toString().trim(),
      phoneNumber: (data['phoneNumber'] ?? '').toString().trim(),
      latitude: number('latitude'),
      longitude: number('longitude'),
      facilities: stringList('facilities'),
      highlights: stringList('highlights'),
      imageUrls: loadedImageUrls,
      coverImageUrl: loadedCoverImageUrl,
      status: (data['status'] ?? 'Active').toString().trim(),
      createdAt: loadedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    String finalCoverImageUrl = coverImageUrl.trim();

    if (finalCoverImageUrl.isEmpty && imageUrls.isNotEmpty) {
      finalCoverImageUrl = imageUrls.first;
    }

    return <String, dynamic>{
      'name': name.trim(),
      'categoryId': categoryId.trim(),
      'categoryName': categoryName.trim(),
      'state': state.trim(),
      'area': area.trim(),
      'description': description.trim(),
      'isFreeEntry': isFreeEntry,
      'malaysianAdultFee': isFreeEntry ? 0 : malaysianAdultFee,
      'malaysianChildFee': isFreeEntry ? 0 : malaysianChildFee,
      'malaysianSeniorFee': isFreeEntry ? 0 : malaysianSeniorFee,
      'nonMalaysianAdultFee': isFreeEntry ? 0 : nonMalaysianAdultFee,
      'nonMalaysianChildFee': isFreeEntry ? 0 : nonMalaysianChildFee,
      'nonMalaysianSeniorFee': isFreeEntry ? 0 : nonMalaysianSeniorFee,
      'openingTime': openingTime.trim(),
      'closingTime': closingTime.trim(),
      'recommendedDuration': recommendedDuration.trim(),
      'address': address.trim(),
      'phoneNumber': phoneNumber.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'facilities': facilities,
      'highlights': highlights,
      'imageUrls': imageUrls,
      'coverImageUrl': finalCoverImageUrl,
      'status': status.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AttractionModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    String? state,
    String? area,
    String? description,
    bool? isFreeEntry,
    double? malaysianAdultFee,
    double? malaysianChildFee,
    double? malaysianSeniorFee,
    double? nonMalaysianAdultFee,
    double? nonMalaysianChildFee,
    double? nonMalaysianSeniorFee,
    String? openingTime,
    String? closingTime,
    String? recommendedDuration,
    String? address,
    String? phoneNumber,
    double? latitude,
    double? longitude,
    List<String>? facilities,
    List<String>? highlights,
    List<String>? imageUrls,
    String? coverImageUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return AttractionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      state: state ?? this.state,
      area: area ?? this.area,
      description: description ?? this.description,
      isFreeEntry: isFreeEntry ?? this.isFreeEntry,
      malaysianAdultFee:
      malaysianAdultFee ?? this.malaysianAdultFee,
      malaysianChildFee:
      malaysianChildFee ?? this.malaysianChildFee,
      malaysianSeniorFee:
      malaysianSeniorFee ?? this.malaysianSeniorFee,
      nonMalaysianAdultFee:
      nonMalaysianAdultFee ?? this.nonMalaysianAdultFee,
      nonMalaysianChildFee:
      nonMalaysianChildFee ?? this.nonMalaysianChildFee,
      nonMalaysianSeniorFee:
      nonMalaysianSeniorFee ?? this.nonMalaysianSeniorFee,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      recommendedDuration:
      recommendedDuration ?? this.recommendedDuration,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      facilities: facilities ?? List<String>.from(this.facilities),
      highlights: highlights ?? List<String>.from(this.highlights),
      imageUrls: imageUrls ?? List<String>.from(this.imageUrls),
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
