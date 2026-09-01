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

  // ============================================================
  // MALAYSIAN ENTRY FEE
  // ============================================================

  final double malaysianAdultFee;
  final double malaysianChildFee;
  final double malaysianSeniorFee;

  // ============================================================
  // NON-MALAYSIAN ENTRY FEE
  // ============================================================

  final double nonMalaysianAdultFee;
  final double nonMalaysianChildFee;
  final double nonMalaysianSeniorFee;

  // ============================================================
  // VISIT INFORMATION
  // ============================================================

  final String openingTime;
  final String closingTime;
  final String recommendedDuration;

  // ============================================================
  // LOCATION / CONTACT
  // ============================================================

  final String address;
  final String phoneNumber;

  // ============================================================
  // FACILITIES / HIGHLIGHTS
  // ============================================================

  final List<String> facilities;
  final List<String> highlights;

  // ============================================================
  // IMAGES
  // ============================================================

  final List<String> imageUrls;
  final String coverImageUrl;

  // ============================================================
  // OTHER
  // ============================================================

  final String status;
  final DateTime createdAt;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

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
    required this.facilities,
    required this.highlights,
    required this.imageUrls,
    required this.coverImageUrl,
    required this.status,
    required this.createdAt,
  });

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory AttractionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    // ==========================================================
    // NUMBER HELPER
    // ==========================================================

    double number(
        String key, {
          String? fallbackKey,
        }) {
      dynamic value = data[key];

      if (value == null && fallbackKey != null) {
        value = data[fallbackKey];
      }

      if (value is num) {
        return value.toDouble();
      }

      if (value is String) {
        return double.tryParse(value) ?? 0;
      }

      return 0;
    }

    // ==========================================================
    // LIST HELPER
    // ==========================================================

    List<String> stringList(String key) {
      final dynamic value = data[key];

      if (value is List) {
        return value
            .where((item) => item != null)
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
      }

      return <String>[];
    }

    // ==========================================================
    // IMAGE URLS
    // ==========================================================

    final List<String> loadedImageUrls =
    stringList('imageUrls');

    String loadedCoverImageUrl =
    (data['coverImageUrl'] ?? '')
        .toString()
        .trim();

    // If coverImageUrl is empty but imageUrls has images,
    // automatically use the first image as cover.
    if (loadedCoverImageUrl.isEmpty &&
        loadedImageUrls.isNotEmpty) {
      loadedCoverImageUrl =
          loadedImageUrls.first;
    }

    // ==========================================================
    // CREATED AT
    // ==========================================================

    DateTime createdAt = DateTime.now();

    final dynamic createdAtValue =
    data['createdAt'];

    if (createdAtValue is Timestamp) {
      createdAt =
          createdAtValue.toDate();
    } else if (createdAtValue is DateTime) {
      createdAt =
          createdAtValue;
    } else if (createdAtValue is String) {
      createdAt =
          DateTime.tryParse(
            createdAtValue,
          ) ??
              DateTime.now();
    }

    // ==========================================================
    // RETURN MODEL
    // ==========================================================

    return AttractionModel(
      id: document.id,

      name:
      (data['name'] ?? '')
          .toString()
          .trim(),

      categoryId:
      (data['categoryId'] ?? '')
          .toString()
          .trim(),

      categoryName:
      (data['categoryName'] ?? '')
          .toString()
          .trim(),

      state:
      (data['state'] ?? '')
          .toString()
          .trim(),

      area:
      (data['area'] ?? '')
          .toString()
          .trim(),

      description:
      (data['description'] ?? '')
          .toString()
          .trim(),

      isFreeEntry:
      data['isFreeEntry'] == true,

      // ========================================================
      // MALAYSIAN FEES
      // ========================================================

      malaysianAdultFee:
      number(
        'malaysianAdultFee',
        fallbackKey: 'adultFee',
      ),

      malaysianChildFee:
      number(
        'malaysianChildFee',
        fallbackKey: 'childFee',
      ),

      malaysianSeniorFee:
      number(
        'malaysianSeniorFee',
      ),

      // ========================================================
      // NON-MALAYSIAN FEES
      // ========================================================

      nonMalaysianAdultFee:
      number(
        'nonMalaysianAdultFee',
        fallbackKey: 'adultFee',
      ),

      nonMalaysianChildFee:
      number(
        'nonMalaysianChildFee',
        fallbackKey: 'childFee',
      ),

      nonMalaysianSeniorFee:
      number(
        'nonMalaysianSeniorFee',
      ),

      // ========================================================
      // VISIT INFORMATION
      // ========================================================

      openingTime:
      (data['openingTime'] ?? '')
          .toString()
          .trim(),

      closingTime:
      (data['closingTime'] ?? '')
          .toString()
          .trim(),

      recommendedDuration:
      (data['recommendedDuration'] ?? '')
          .toString()
          .trim(),

      // ========================================================
      // LOCATION / CONTACT
      // ========================================================

      address:
      (data['address'] ?? '')
          .toString()
          .trim(),

      phoneNumber:
      (data['phoneNumber'] ?? '')
          .toString()
          .trim(),

      // ========================================================
      // FACILITIES / HIGHLIGHTS
      // ========================================================

      facilities:
      stringList(
        'facilities',
      ),

      highlights:
      stringList(
        'highlights',
      ),

      // ========================================================
      // IMAGES
      // ========================================================

      imageUrls:
      loadedImageUrls,

      coverImageUrl:
      loadedCoverImageUrl,

      // ========================================================
      // OTHER
      // ========================================================

      status:
      (data['status'] ?? 'Active')
          .toString()
          .trim(),

      createdAt:
      createdAt,
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    String finalCoverImageUrl =
    coverImageUrl.trim();

    // Safety:
    // if cover image is empty but images exist,
    // automatically save first image as cover.
    if (finalCoverImageUrl.isEmpty &&
        imageUrls.isNotEmpty) {
      finalCoverImageUrl =
          imageUrls.first;
    }

    return <String, dynamic>{
      // ========================================================
      // BASIC INFORMATION
      // ========================================================

      'name':
      name.trim(),

      'categoryId':
      categoryId.trim(),

      'categoryName':
      categoryName.trim(),

      'state':
      state.trim(),

      'area':
      area.trim(),

      'description':
      description.trim(),

      // ========================================================
      // ENTRY FEE
      // ========================================================

      'isFreeEntry':
      isFreeEntry,

      'malaysianAdultFee':
      isFreeEntry
          ? 0
          : malaysianAdultFee,

      'malaysianChildFee':
      isFreeEntry
          ? 0
          : malaysianChildFee,

      'malaysianSeniorFee':
      isFreeEntry
          ? 0
          : malaysianSeniorFee,

      'nonMalaysianAdultFee':
      isFreeEntry
          ? 0
          : nonMalaysianAdultFee,

      'nonMalaysianChildFee':
      isFreeEntry
          ? 0
          : nonMalaysianChildFee,

      'nonMalaysianSeniorFee':
      isFreeEntry
          ? 0
          : nonMalaysianSeniorFee,

      // ========================================================
      // VISIT INFORMATION
      // ========================================================

      'openingTime':
      openingTime.trim(),

      'closingTime':
      closingTime.trim(),

      'recommendedDuration':
      recommendedDuration.trim(),

      // ========================================================
      // LOCATION / CONTACT
      // ========================================================

      'address':
      address.trim(),

      'phoneNumber':
      phoneNumber.trim(),

      // ========================================================
      // FACILITIES / HIGHLIGHTS
      // ========================================================

      'facilities':
      facilities,

      'highlights':
      highlights,

      // ========================================================
      // IMAGES
      // ========================================================

      'imageUrls':
      imageUrls,

      'coverImageUrl':
      finalCoverImageUrl,

      // ========================================================
      // STATUS / DATE
      // ========================================================

      'status':
      status.trim(),

      'createdAt':
      Timestamp.fromDate(
        createdAt,
      ),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

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
    List<String>? facilities,
    List<String>? highlights,
    List<String>? imageUrls,
    String? coverImageUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return AttractionModel(
      id:
      id ?? this.id,

      name:
      name ?? this.name,

      categoryId:
      categoryId ??
          this.categoryId,

      categoryName:
      categoryName ??
          this.categoryName,

      state:
      state ?? this.state,

      area:
      area ?? this.area,

      description:
      description ??
          this.description,

      isFreeEntry:
      isFreeEntry ??
          this.isFreeEntry,

      malaysianAdultFee:
      malaysianAdultFee ??
          this.malaysianAdultFee,

      malaysianChildFee:
      malaysianChildFee ??
          this.malaysianChildFee,

      malaysianSeniorFee:
      malaysianSeniorFee ??
          this.malaysianSeniorFee,

      nonMalaysianAdultFee:
      nonMalaysianAdultFee ??
          this.nonMalaysianAdultFee,

      nonMalaysianChildFee:
      nonMalaysianChildFee ??
          this.nonMalaysianChildFee,

      nonMalaysianSeniorFee:
      nonMalaysianSeniorFee ??
          this.nonMalaysianSeniorFee,

      openingTime:
      openingTime ??
          this.openingTime,

      closingTime:
      closingTime ??
          this.closingTime,

      recommendedDuration:
      recommendedDuration ??
          this.recommendedDuration,

      address:
      address ??
          this.address,

      phoneNumber:
      phoneNumber ??
          this.phoneNumber,

      facilities:
      facilities ??
          List<String>.from(
            this.facilities,
          ),

      highlights:
      highlights ??
          List<String>.from(
            this.highlights,
          ),

      imageUrls:
      imageUrls ??
          List<String>.from(
            this.imageUrls,
          ),

      coverImageUrl:
      coverImageUrl ??
          this.coverImageUrl,

      status:
      status ??
          this.status,

      createdAt:
      createdAt ??
          this.createdAt,
    );
  }
}