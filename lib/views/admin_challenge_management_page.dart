import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'admin_home_page.dart';
import 'admin_login_page.dart';
import 'admin_sidebar.dart';
import 'admin_stamp_management_page.dart';

class AdminChallengeManagementPage extends StatefulWidget {
  const AdminChallengeManagementPage({super.key});

  @override
  State<AdminChallengeManagementPage> createState() =>
      _AdminChallengeManagementPageState();
}

class _AdminChallengeManagementPageState
    extends State<AdminChallengeManagementPage> {
  static const Color mainGreen =
  Color(0xFF2E7D32);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // CHALLENGE STREAM
  // ============================================================

  Stream<List<_AdminChallengeRecord>>
  _watchChallenges() {
    return _firestore
        .collection('challenges')
        .snapshots()
        .map((snapshot) {
      final records =
      snapshot.docs.map((doc) {
        final data = doc.data();

        final requiredIds =
        data['requiredAttractionIds'];

        return _AdminChallengeRecord(
          id: doc.id,
          title:
          (data['title'] ?? '')
              .toString(),
          description:
          (data['description'] ?? '')
              .toString(),
          challengeType:
          (data['challengeType'] ?? '')
              .toString(),
          targetValue:
          (data['targetValue'] as num?)
              ?.toDouble() ??
              1,
          rewardPoints:
          (data['rewardPoints'] as num?)
              ?.toInt() ??
              0,
          rewardXp:
          (data['rewardXp'] as num?)
              ?.toInt() ??
              0,
          imageName:
          (data['imageName'] ?? '')
              .toString(),
          imageUrl:
          (data['imageUrl'] ?? '')
              .toString(),
          iconType:
          (data['iconType'] ??
              'heritage')
              .toString(),
          trackingSource:
          (data['trackingSource'] ??
              'location')
              .toString(),
          requiredAttractionIds:
          requiredIds is List
              ? requiredIds
              .map(
                (value) =>
                value.toString(),
          )
              .toList()
              : [],
          isActive:
          data['isActive'] == true,
          displayOrder:
          (data['displayOrder']
          as num?)
              ?.toInt() ??
              999,
          unit:
          (data['unit'] ?? '')
              .toString(),
          badgeName:
          (data['badgeName'] ?? '')
              .toString(),
          badgeDescription:
          (data['badgeDescription'] ??
              '')
              .toString(),
          badgeImageUrl:
          (data['badgeImageUrl'] ??
              '')
              .toString(),
          startAt:
          data['startAt']
          is Timestamp
              ? (data['startAt']
          as Timestamp)
              .toDate()
              : null,
          endAt:
          data['endAt']
          is Timestamp
              ? (data['endAt']
          as Timestamp)
              .toDate()
              : null,
        );
      }).toList();

      records.sort(
            (a, b) => a.displayOrder
            .compareTo(
          b.displayOrder,
        ),
      );

      return records;
    });
  }

  // ============================================================
  // ATTRACTIONS
  // ============================================================

  Future<List<_AttractionOption>>
  _loadAttractions() async {
    final snapshot = await _firestore
        .collection('attractions')
        .get();

    final result =
    snapshot.docs.map((doc) {
      final data = doc.data();

      return _AttractionOption(
        id: doc.id,
        name:
        (data['name'] ?? '')
            .toString()
            .trim(),
      );
    }).where((item) {
      return item.name.isNotEmpty;
    }).toList();

    result.sort(
          (a, b) => a.name
          .toLowerCase()
          .compareTo(
        b.name.toLowerCase(),
      ),
    );

    return result;
  }

  // ============================================================
// CHALLENGE IMAGE UPLOAD
// ============================================================

  Future<String?> _pickAndUploadChallengeImage({
    required String challengeId,
  }) async {
    try {
      final file = await fp.FilePicker.pickFile(
        type: fp.FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
        ],
      );

      if (file == null) {
        return null;
      }

      final extension =
      (file.extension ?? '').toLowerCase();

      const allowedExtensions = {
        'jpg',
        'jpeg',
        'png',
      };

      if (!allowedExtensions.contains(extension)) {
        _showMessage(
          'Only JPG, JPEG and PNG images are allowed.',
        );
        return null;
      }

      const maxFileSize = 5 * 1024 * 1024;

      final fileSize = await file.length();

      if (fileSize > maxFileSize) {
        _showMessage(
          'Image must be 5 MB or smaller.',
        );
        return null;
      }

      final Uint8List bytes =
      await file.readAsBytes();

      final contentType =
      extension == 'png'
          ? 'image/png'
          : 'image/jpeg';

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final storageRef = _storage.ref().child(
        'challenge_images/'
            '$challengeId/'
            'challenge_$timestamp.$extension',
      );

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'type': 'challenge_image',
          'challengeId': challengeId,
        },
      );

      final snapshot =
      await storageRef.putData(
        bytes,
        metadata,
      );

      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      _showMessage(
        'Upload failed: ${e.message ?? e.code}',
      );
      return null;
    } catch (e) {
      _showMessage(
        'Upload failed: $e',
      );
      return null;
    }
  }

  // ============================================================
  // BADGE UPLOAD
  // ============================================================

  Future<String?>
  _pickAndUploadBadgeImage({
    required String challengeId,
  }) async {
    try {
      final file =
      await fp.FilePicker.pickFile(
        type: fp.FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
        ],
      );

      if (file == null) {
        return null;
      }

      final extension =
      (file.extension ?? '')
          .toLowerCase();

      const allowedExtensions = {
        'jpg',
        'jpeg',
        'png',
      };

      if (!allowedExtensions
          .contains(extension)) {
        _showMessage(
          'Only JPG, JPEG and PNG images are allowed.',
        );

        return null;
      }

      const maxFileSize =
          5 * 1024 * 1024;

      final fileSize =
      await file.length();

      if (fileSize > maxFileSize) {
        _showMessage(
          'Image must be 5 MB or smaller.',
        );

        return null;
      }

      final Uint8List bytes =
      await file.readAsBytes();

      final contentType =
      extension == 'png'
          ? 'image/png'
          : 'image/jpeg';

      final timestamp =
          DateTime.now()
              .millisecondsSinceEpoch;

      final storageRef =
      _storage.ref().child(
        'challenge_badges/'
            '$challengeId/'
            'badge_$timestamp.$extension',
      );

      final metadata =
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'type':
          'challenge_badge',
          'challengeId':
          challengeId,
        },
      );

      final snapshot =
      await storageRef.putData(
        bytes,
        metadata,
      );

      return await snapshot.ref
          .getDownloadURL();
    } on FirebaseException catch (e) {
      _showMessage(
        'Upload failed: '
            '${e.message ?? e.code}',
      );

      return null;
    } catch (e) {
      _showMessage(
        'Upload failed: $e',
      );

      return null;
    }
  }

  // ============================================================
  // AI BADGE
  // ============================================================

  Future<String?> _generateBadgeImage({
    required String challengeId,
    required String challengeTitle,
    required String badgeName,
    required String badgeDescription,
  }) async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage(
          'Please sign in again.',
        );

        return null;
      }

      final idToken =
      await user.getIdToken();

      if (idToken == null ||
          idToken.isEmpty) {
        _showMessage(
          'Unable to get authentication token.',
        );

        return null;
      }

      const functionUrl =
          'https://us-central1-ecotravel-5ad49.cloudfunctions.net/'
          'generateBadgeImage';

      final response =
      await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type':
          'application/json',
          'Authorization':
          'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {
            'challengeId':
            challengeId,
            'challengeTitle':
            challengeTitle,
            'badgeName':
            badgeName,
            'badgeDescription':
            badgeDescription,
          },
        }),
      );

      debugPrint(
        'Generate badge status: '
            '${response.statusCode}',
      );

      debugPrint(
        'Generate badge response: '
            '${response.body}',
      );

      if (response.body.isEmpty) {
        _showMessage(
          'Server returned an empty response.',
        );

        return null;
      }

      final dynamic decoded =
      jsonDecode(response.body);

      if (decoded is! Map) {
        _showMessage(
          'Invalid server response.',
        );

        return null;
      }

      final responseMap =
      Map<String, dynamic>.from(
        decoded,
      );

      if (responseMap['error'] != null) {
        final error =
        responseMap['error'];

        String message =
            'Unable to generate badge.';

        if (error is Map) {
          final errorMap =
          Map<String, dynamic>.from(
            error,
          );

          message =
              (errorMap['message'] ??
                  errorMap['status'] ??
                  message)
                  .toString();
        }

        _showMessage(
          'Generate failed: $message',
        );

        return null;
      }

      final result =
      responseMap['result'];

      if (result is! Map) {
        _showMessage(
          'Invalid AI response.',
        );

        return null;
      }

      final resultMap =
      Map<String, dynamic>.from(
        result,
      );

      final imageUrl =
      (resultMap['imageUrl'] ?? '')
          .toString()
          .trim();

      if (imageUrl.isEmpty) {
        _showMessage(
          'AI did not return a badge image.',
        );

        return null;
      }

      return imageUrl;
    } catch (e, stackTrace) {
      debugPrint(
        'Generate badge error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      _showMessage(
        'Generate failed: $e',
      );

      return null;
    }
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<void>
  _openCreateChallengeDialog() async {
    final challengeRef =
    _firestore
        .collection('challenges')
        .doc();

    await _openChallengeDialog(
      challengeId: challengeRef.id,
      existing: null,
    );
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void>
  _openEditChallengeDialog(
      _AdminChallengeRecord record,
      ) async {
    await _openChallengeDialog(
      challengeId: record.id,
      existing: record,
    );
  }

  // ============================================================
  // CREATE / EDIT DIALOG
  // ============================================================

  Future<void>
  _openChallengeDialog({
    required String challengeId,
    required _AdminChallengeRecord?
    existing,
  }) async {
    final isEditing =
        existing != null;

    final attractions =
    await _loadAttractions();

    if (!mounted) return;

    final titleController =
    TextEditingController(
      text: existing?.title ?? '',
    );

    final descriptionController =
    TextEditingController(
      text:
      existing?.description ?? '',
    );

    final targetController =
    TextEditingController(
      text: existing == null
          ? '1'
          : existing.targetValue
          .toString(),
    );

    final rewardPointsController =
    TextEditingController(
      text: existing == null
          ? '100'
          : existing.rewardPoints
          .toString(),
    );

    final rewardXpController =
    TextEditingController(
      text: existing == null
          ? '100'
          : existing.rewardXp
          .toString(),
    );


    final unitController =
    TextEditingController(
      text: existing?.unit ??
          'attractions',
    );

    final badgeNameController =
    TextEditingController(
      text:
      existing?.badgeName ?? '',
    );

    final badgeDescriptionController =
    TextEditingController(
      text:
      existing?.badgeDescription ??
          '',
    );

    String challengeType =
    existing?.challengeType
        .isNotEmpty ==
        true
        ? existing!.challengeType
        : 'visit_count';

    String trackingSource =
    existing?.trackingSource
        .isNotEmpty ==
        true
        ? existing!.trackingSource
        : 'location';

    bool isActive =
        existing?.isActive ?? true;

    // Challenge's own image
    String challengeImageUrl =
        existing?.imageUrl ?? '';

    String challengeImageName =
        existing?.imageName ?? '';

    // Badge reward image
    String badgeImageUrl =
        existing?.badgeImageUrl ?? '';

    bool isUploadingChallengeImage = false;

    final selectedAttractionIds =
    <String>{
      ...(existing
          ?.requiredAttractionIds ??
          []),
    };

    String attractionSearch = '';

    bool isUploading = false;
    bool isGenerating = false;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              dialogContext,
              setDialogState,
              ) {
            final filteredAttractions =
            attractions.where((item) {
              if (attractionSearch
                  .trim()
                  .isEmpty) {
                return true;
              }

              return item.name
                  .toLowerCase()
                  .contains(
                attractionSearch
                    .trim()
                    .toLowerCase(),
              );
            }).toList();

            final needsAttractionSelection =
                challengeType ==
                    'visit_specific';

            return AlertDialog(
              insetPadding:
              const EdgeInsets.all(
                24,
              ),
              title: Text(
                isEditing
                    ? 'Edit Challenge'
                    : 'Create New Challenge',
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 1050,
                height: 680,
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    // ==========================
                    // LEFT SIDE
                    // ==========================

                    Expanded(
                      flex: 5,
                      child:
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            const Text(
                              'Challenge Information',
                              style:
                              TextStyle(
                                fontSize:
                                18,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _label(
                              'Challenge Title',
                            ),

                            TextField(
                              controller:
                              titleController,
                              decoration:
                              _inputDecoration(
                                'Enter challenge title',
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            _label(
                              'Description',
                            ),

                            TextField(
                              controller:
                              descriptionController,
                              maxLines: 3,
                              decoration:
                              _inputDecoration(
                                'Enter challenge description',
                              ),
                            ),

                            const SizedBox(height: 18),

                            _label('Challenge Image'),

                            Container(
                              width: double.infinity,
                              height: 190,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: challengeImageUrl.isNotEmpty
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  challengeImageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    if (challengeImageName.isNotEmpty) {
                                      return Image.asset(
                                        'assets/images/$challengeImageName',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            _challengeImagePlaceholder(),
                                      );
                                    }
                                    return _challengeImagePlaceholder();
                                  },
                                ),
                              )
                                  : challengeImageName.isNotEmpty
                                  ? ClipRRect(
                                borderRadius:
                                BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/$challengeImageName',
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _challengeImagePlaceholder(),
                                ),
                              )
                                  : _challengeImagePlaceholder(),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                isUploadingChallengeImage
                                    ? null
                                    : () async {
                                  setDialogState(() {
                                    isUploadingChallengeImage =
                                    true;
                                  });

                                  final url =
                                  await _pickAndUploadChallengeImage(
                                    challengeId: challengeId,
                                  );

                                  if (!dialogContext.mounted) {
                                    return;
                                  }

                                  setDialogState(() {
                                    isUploadingChallengeImage =
                                    false;

                                    if (url != null) {
                                      challengeImageUrl = url;
                                    }
                                  });
                                },
                                icon: isUploadingChallengeImage
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Icon(
                                  Icons.upload_outlined,
                                ),
                                label: const Text(
                                  'Upload Challenge Image',
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Supported: JPG, JPEG, PNG • Maximum 5 MB',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 18),

                            const SizedBox(
                              height: 14,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      _label(
                                        'Challenge Type',
                                      ),
                                      DropdownButtonFormField<
                                          String>(
                                        initialValue:
                                        challengeType,
                                        decoration:
                                        _inputDecoration(
                                          '',
                                        ),
                                        items:
                                        const [
                                          DropdownMenuItem(
                                            value:
                                            'visit_count',
                                            child:
                                            Text(
                                              'Visit Count',
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value:
                                            'visit_specific',
                                            child:
                                            Text(
                                              'Visit Specific Attractions',
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value:
                                            'carbon_saved',
                                            child:
                                            Text(
                                              'Carbon Saved',
                                            ),
                                          ),
                                        ],
                                        onChanged:
                                            (value) {
                                          if (value ==
                                              null) {
                                            return;
                                          }

                                          setDialogState(
                                                () {
                                              challengeType =
                                                  value;

                                              if (value ==
                                                  'carbon_saved') {
                                                unitController
                                                    .text =
                                                'kg CO₂';
                                              } else {
                                                unitController
                                                    .text =
                                                'attractions';
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                Expanded(
                                  child:
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      _label(
                                        'Target Value',
                                      ),
                                      TextField(
                                        controller:
                                        targetController,
                                        keyboardType:
                                        TextInputType
                                            .number,
                                        decoration:
                                        _inputDecoration(
                                          'e.g. 3',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      _label(
                                        'Unit',
                                      ),
                                      TextField(
                                        controller:
                                        unitController,
                                        decoration:
                                        _inputDecoration(
                                          'e.g. attractions',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                Expanded(
                                  child:
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      _label(
                                        'Tracking Source',
                                      ),
                                      DropdownButtonFormField<
                                          String>(
                                        initialValue:
                                        trackingSource,
                                        decoration:
                                        _inputDecoration(
                                          '',
                                        ),
                                        items:
                                        const [
                                          DropdownMenuItem(
                                            value:
                                            'location',
                                            child:
                                            Text(
                                              'Location',
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value:
                                            'carbon',
                                            child:
                                            Text(
                                              'Carbon Saving',
                                            ),
                                          ),
                                        ],
                                        onChanged:
                                            (value) {
                                          if (value ==
                                              null) {
                                            return;
                                          }

                                          setDialogState(
                                                () {
                                              trackingSource =
                                                  value;
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      _label(
                                        'Reward Points',
                                      ),
                                      TextField(
                                        controller:
                                        rewardPointsController,
                                        keyboardType:
                                        TextInputType
                                            .number,
                                        decoration:
                                        _inputDecoration(
                                          'e.g. 300',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                Expanded(
                                  child:
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      _label(
                                        'Reward XP',
                                      ),
                                      TextField(
                                        controller:
                                        rewardXpController,
                                        keyboardType:
                                        TextInputType
                                            .number,
                                        decoration:
                                        _inputDecoration(
                                          'e.g. 200',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              ],
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            SwitchListTile(
                              contentPadding:
                              EdgeInsets.zero,
                              title:
                              const Text(
                                'Active Challenge',
                                style:
                                TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),
                              subtitle:
                              const Text(
                                'Active challenges are visible to visitors.',
                              ),
                              value:
                              isActive,
                              activeThumbColor:
                              mainGreen,
                              onChanged:
                                  (value) {
                                setDialogState(
                                      () {
                                    isActive =
                                        value;
                                  },
                                );
                              },
                            ),

                            if (needsAttractionSelection) ...[
                              const Divider(
                                height: 32,
                              ),

                              _label(
                                'Required Attractions',
                              ),

                              TextField(
                                onChanged:
                                    (value) {
                                  setDialogState(
                                        () {
                                      attractionSearch =
                                          value;
                                    },
                                  );
                                },
                                decoration:
                                _inputDecoration(
                                  'Search attraction...',
                                ).copyWith(
                                  prefixIcon:
                                  const Icon(
                                    Icons.search,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              Container(
                                height: 210,
                                decoration:
                                BoxDecoration(
                                  border:
                                  Border.all(
                                    color:
                                    Colors.grey
                                        .shade300,
                                  ),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    10,
                                  ),
                                ),
                                child:
                                ListView.builder(
                                  itemCount:
                                  filteredAttractions
                                      .length,
                                  itemBuilder:
                                      (
                                      context,
                                      index,
                                      ) {
                                    final item =
                                    filteredAttractions[
                                    index];

                                    final selected =
                                    selectedAttractionIds
                                        .contains(
                                      item.id,
                                    );

                                    return CheckboxListTile(
                                      dense:
                                      true,
                                      value:
                                      selected,
                                      activeColor:
                                      mainGreen,
                                      title:
                                      Text(
                                        item.name,
                                      ),
                                      onChanged:
                                          (value) {
                                        setDialogState(
                                              () {
                                            if (value ==
                                                true) {
                                              selectedAttractionIds
                                                  .add(
                                                item.id,
                                              );
                                            } else {
                                              selectedAttractionIds
                                                  .remove(
                                                item.id,
                                              );
                                            }
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              Text(
                                '${selectedAttractionIds.length} attraction(s) selected',
                                style:
                                TextStyle(
                                  fontSize:
                                  12,
                                  color:
                                  Colors.grey
                                      .shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 32,
                    ),

                    // ==========================
                    // RIGHT SIDE
                    // ==========================

                    Expanded(
                      flex: 4,
                      child:
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            const Text(
                              'Badge Reward',
                              style:
                              TextStyle(
                                fontSize:
                                18,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _label(
                              'Badge Name',
                            ),

                            TextField(
                              controller:
                              badgeNameController,
                              decoration:
                              _inputDecoration(
                                'e.g. Heritage Explorer',
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            _label(
                              'Badge Description',
                            ),

                            TextField(
                              controller:
                              badgeDescriptionController,
                              maxLines: 3,
                              decoration:
                              _inputDecoration(
                                'Describe the badge reward',
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _label(
                              'Badge Preview',
                            ),

                            Container(
                              width:
                              double.infinity,
                              height: 260,
                              decoration:
                              BoxDecoration(
                                color:
                                Colors.grey
                                    .shade100,
                                border:
                                Border.all(
                                  color:
                                  Colors.grey
                                      .shade300,
                                ),
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  14,
                                ),
                              ),
                              child: badgeImageUrl
                                  .isEmpty
                                  ? Column(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                                children: [
                                  Icon(
                                    Icons
                                        .military_tech_outlined,
                                    size:
                                    64,
                                    color:
                                    Colors.grey
                                        .shade400,
                                  ),
                                  const SizedBox(
                                    height:
                                    10,
                                  ),
                                  Text(
                                    'No badge image yet',
                                    style:
                                    TextStyle(
                                      color:
                                      Colors.grey
                                          .shade600,
                                    ),
                                  ),
                                ],
                              )
                                  : ClipRRect(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  14,
                                ),
                                child:
                                Image.network(
                                  badgeImageUrl,
                                  fit:
                                  BoxFit
                                      .contain,
                                  errorBuilder:
                                      (
                                      context,
                                      error,
                                      stackTrace,
                                      ) {
                                    return const Center(
                                      child:
                                      Text(
                                        'Unable to load image',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                  OutlinedButton.icon(
                                    onPressed:
                                    isUploading ||
                                        isGenerating
                                        ? null
                                        : () async {
                                      setDialogState(
                                            () {
                                          isUploading =
                                          true;
                                        },
                                      );

                                      final url =
                                      await _pickAndUploadBadgeImage(
                                        challengeId:
                                        challengeId,
                                      );

                                      if (!dialogContext
                                          .mounted) {
                                        return;
                                      }

                                      setDialogState(
                                            () {
                                          isUploading =
                                          false;

                                          if (url !=
                                              null) {
                                            badgeImageUrl =
                                                url;
                                          }
                                        },
                                      );
                                    },
                                    icon:
                                    isUploading
                                        ? const SizedBox(
                                      width:
                                      18,
                                      height:
                                      18,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth:
                                        2,
                                      ),
                                    )
                                        : const Icon(
                                      Icons
                                          .upload_outlined,
                                    ),
                                    label:
                                    const Text(
                                      'Upload Badge',
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                Expanded(
                                  child:
                                  ElevatedButton.icon(
                                    style:
                                    ElevatedButton
                                        .styleFrom(
                                      backgroundColor:
                                      mainGreen,
                                      foregroundColor:
                                      Colors.white,
                                    ),
                                    onPressed:
                                    isUploading ||
                                        isGenerating
                                        ? null
                                        : () async {
                                      final challengeTitle =
                                      titleController
                                          .text
                                          .trim();

                                      final badgeName =
                                      badgeNameController
                                          .text
                                          .trim();

                                      final badgeDescription =
                                      badgeDescriptionController
                                          .text
                                          .trim();

                                      if (challengeTitle
                                          .isEmpty ||
                                          badgeName
                                              .isEmpty) {
                                        _showMessage(
                                          'Enter the challenge title and badge name first.',
                                        );
                                        return;
                                      }

                                      setDialogState(
                                            () {
                                          isGenerating =
                                          true;
                                        },
                                      );

                                      final url =
                                      await _generateBadgeImage(
                                        challengeId:
                                        challengeId,
                                        challengeTitle:
                                        challengeTitle,
                                        badgeName:
                                        badgeName,
                                        badgeDescription:
                                        badgeDescription,
                                      );

                                      if (!dialogContext
                                          .mounted) {
                                        return;
                                      }

                                      setDialogState(
                                            () {
                                          isGenerating =
                                          false;

                                          if (url !=
                                              null) {
                                            badgeImageUrl =
                                                url;
                                          }
                                        },
                                      );
                                    },
                                    icon:
                                    isGenerating
                                        ? const SizedBox(
                                      width:
                                      18,
                                      height:
                                      18,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth:
                                        2,
                                        color:
                                        Colors.white,
                                      ),
                                    )
                                        : const Icon(
                                      Icons
                                          .auto_awesome,
                                    ),
                                    label:
                                    const Text(
                                      'Generate Badge',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Text(
                              'Supported: JPG, JPEG, PNG • Maximum 5 MB • 1 image only',
                              style:
                              TextStyle(
                                fontSize:
                                12,
                                color:
                                Colors.grey
                                    .shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ============================
              // ACTIONS
              // ============================

              actions: [
                TextButton(
                  onPressed:
                  isSaving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text(
                    'Cancel',
                  ),
                ),

                ElevatedButton(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    mainGreen,
                    foregroundColor:
                    Colors.white,
                  ),
                  onPressed:
                  isSaving
                      ? null
                      : () async {
                    final title =
                    titleController
                        .text
                        .trim();

                    final description =
                    descriptionController
                        .text
                        .trim();

                    final badgeName =
                    badgeNameController
                        .text
                        .trim();

                    final badgeDescription =
                    badgeDescriptionController
                        .text
                        .trim();

                    final targetValue =
                    double.tryParse(
                      targetController
                          .text
                          .trim(),
                    );

                    final rewardPoints =
                    int.tryParse(
                      rewardPointsController
                          .text
                          .trim(),
                    );

                    final rewardXp =
                    int.tryParse(
                      rewardXpController
                          .text
                          .trim(),
                    );


                    if (title.isEmpty) {
                      _showMessage(
                        'Challenge title is required.',
                      );
                      return;
                    }

                    if (description
                        .isEmpty) {
                      _showMessage(
                        'Challenge description is required.',
                      );
                      return;
                    }

                    if (targetValue ==
                        null ||
                        targetValue <=
                            0) {
                      _showMessage(
                        'Target value must be greater than 0.',
                      );
                      return;
                    }

                    if (rewardPoints ==
                        null ||
                        rewardPoints <
                            0) {
                      _showMessage(
                        'Enter a valid reward point value.',
                      );
                      return;
                    }

                    if (rewardXp ==
                        null ||
                        rewardXp <
                            0) {
                      _showMessage(
                        'Enter a valid reward XP value.',
                      );
                      return;
                    }

                    if (challengeType ==
                        'visit_specific' &&
                        selectedAttractionIds
                            .isEmpty) {
                      _showMessage(
                        'Select at least one required attraction.',
                      );
                      return;
                    }

                    if (challengeImageUrl.isEmpty) {
                      _showMessage(
                        'Upload a challenge image.',
                      );
                      return;
                    }

                    if (badgeName
                        .isEmpty) {
                      _showMessage(
                        'Badge name is required.',
                      );
                      return;
                    }

                    if (badgeDescription
                        .isEmpty) {
                      _showMessage(
                        'Badge description is required.',
                      );
                      return;
                    }

                    if (badgeImageUrl
                        .isEmpty) {
                      _showMessage(
                        'Upload or generate a badge image.',
                      );
                      return;
                    }

                    setDialogState(
                          () {
                        isSaving =
                        true;
                      },
                    );

                    try {
                      final data =
                      <String,
                          dynamic>{
                        'title':
                        title,
                        'description':
                        description,
                        'challengeType':
                        challengeType,
                        'targetValue':
                        targetValue,
                        'rewardPoints':
                        rewardPoints,
                        'rewardXp':
                        rewardXp,
                        'imageName':
                        challengeImageName,

                        'imageUrl':
                        challengeImageUrl,
                        'iconType':
                        existing?.iconType ??
                            'heritage',
                        'trackingSource':
                        trackingSource,
                        'requiredAttractionIds':
                        challengeType ==
                            'visit_specific'
                            ? selectedAttractionIds
                            .toList()
                            : <
                            String>[],
                        'isActive':
                        isActive,
                        'displayOrder':
                        existing?.displayOrder ?? 999,
                        'unit':
                        unitController
                            .text
                            .trim(),
                        'badgeName':
                        badgeName,
                        'badgeDescription':
                        badgeDescription,
                        'badgeImageUrl':
                        badgeImageUrl,
                        'startAt':
                        existing
                            ?.startAt,
                        'endAt':
                        existing
                            ?.endAt,
                      };

                      await _firestore
                          .collection(
                        'challenges',
                      )
                          .doc(
                        challengeId,
                      )
                          .set(
                        data,
                        SetOptions(
                          merge:
                          true,
                        ),
                      );

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                      );

                      _showMessage(
                        isEditing
                            ? 'Challenge updated successfully.'
                            : 'Challenge created successfully.',
                      );
                    } catch (e) {
                      setDialogState(
                            () {
                          isSaving =
                          false;
                        },
                      );

                      _showMessage(
                        'Unable to save challenge: $e',
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color:
                      Colors.white,
                    ),
                  )
                      : Text(
                    isEditing
                        ? 'Save Changes'
                        : 'Create Challenge',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    targetController.dispose();
    rewardPointsController
        .dispose();
    rewardXpController.dispose();
    // displayOrderController
    //     .dispose();
    unitController.dispose();
    badgeNameController.dispose();
    badgeDescriptionController
        .dispose();
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteChallenge(
      _AdminChallengeRecord record,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Delete Challenge',
          ),
          content: Text(
            'Delete "${record.title}"?\n\n'
                'This removes the challenge definition. '
                'Existing user reward history will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                Colors.red,
                foregroundColor:
                Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
              const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('challenges')
          .doc(record.id)
          .delete();

      _showMessage(
        'Challenge deleted.',
      );
    } catch (e) {
      _showMessage(
        'Unable to delete challenge: $e',
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await FirebaseAuth.instance
        .signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const AdminLoginPage(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF6F7F9),
      body: Row(
        children: [
          AdminSidebar(
            selectedPage: 'challenge',

            onDashboardTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminHomePage(),
                ),
              );
            },

            onAttractionTap: () {},
            onCategoryTap: () {},
            onCulturalHeritageTap: () {},
            onReportTap: () {},
            onStampTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AdminStampManagementPage(),
                ),
              );
            },

            onChallengeTap: () {},

            onLogoutTap: _logout,
          ),

          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.all(
                28,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              'Challenge Management',
                              style:
                              TextStyle(
                                fontSize:
                                30,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                            SizedBox(
                              height: 4,
                            ),
                            Text(
                              'Create challenges and manage badge rewards.',
                              style:
                              TextStyle(
                                color:
                                Colors.grey,
                                fontSize:
                                14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        width: 220,
                        child:
                        ElevatedButton.icon(
                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            mainGreen,
                            foregroundColor:
                            Colors.white,
                            padding:
                            const EdgeInsets
                                .symmetric(
                              vertical:
                              16,
                            ),
                          ),
                          onPressed: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;

                              _openCreateChallengeDialog();
                            });
                          },
                          icon:
                          const Icon(
                            Icons.add,
                          ),
                          label:
                          const Text(
                            'Create Challenge',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  TextField(
                    controller:
                    _searchController,
                    onChanged:
                        (value) {
                      setState(() {
                        _searchText =
                            value;
                      });
                    },
                    decoration:
                    InputDecoration(
                      hintText:
                      'Search challenges...',
                      prefixIcon:
                      const Icon(
                        Icons.search,
                      ),
                      filled:
                      true,
                      fillColor:
                      Colors.white,
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          10,
                        ),
                        borderSide:
                        BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Expanded(
                    child: StreamBuilder<
                        List<
                            _AdminChallengeRecord>>(
                      stream:
                      _watchChallenges(),
                      builder:
                          (
                          context,
                          snapshot,
                          ) {
                        if (snapshot
                            .connectionState ==
                            ConnectionState
                                .waiting) {
                          return const Center(
                            child:
                            CircularProgressIndicator(),
                          );
                        }

                        if (snapshot
                            .hasError) {
                          return Center(
                            child: Text(
                              'Unable to load challenges:\n${snapshot.error}',
                            ),
                          );
                        }

                        final all =
                            snapshot.data ??
                                [];

                        final query =
                        _searchText
                            .trim()
                            .toLowerCase();

                        final challenges =
                        all.where(
                              (record) {
                            if (query
                                .isEmpty) {
                              return true;
                            }

                            return record
                                .title
                                .toLowerCase()
                                .contains(
                              query,
                            ) ||
                                record
                                    .badgeName
                                    .toLowerCase()
                                    .contains(
                                  query,
                                );
                          },
                        ).toList();

                        if (challenges
                            .isEmpty) {
                          return const Center(
                            child:
                            Text(
                              'No challenges found.',
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount:
                          challenges
                              .length,
                          separatorBuilder:
                              (
                              context,
                              index,
                              ) =>
                          const SizedBox(
                            height:
                            12,
                          ),
                          itemBuilder:
                              (
                              context,
                              index,
                              ) {
                            final item =
                            challenges[
                            index];

                            return _challengeCard(
                              item,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(
      _AdminChallengeRecord item,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color:
          Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Challenge image (NOT badge image)
          Container(
            width: 110,
            height: 82,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: item.imageUrl.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  if (item.imageName.isNotEmpty) {
                    return Image.asset(
                      'assets/images/${item.imageName}',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          _challengeImagePlaceholder(),
                    );
                  }
                  return _challengeImagePlaceholder();
                },
              ),
            )
                : item.imageName.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/${item.imageName}',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    _challengeImagePlaceholder(),
              ),
            )
                : _challengeImagePlaceholder(),
          ),

          const SizedBox(
            width:
            18,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  item.title,
                  style:
                  const TextStyle(
                    fontSize:
                    17,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                  4,
                ),

                Text(
                  item.description,
                  maxLines:
                  2,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  TextStyle(
                    color:
                    Colors.grey.shade700,
                  ),
                ),

                const SizedBox(
                  height:
                  8,
                ),

                Wrap(
                  spacing:
                  14,
                  runSpacing:
                  6,
                  children: [
                    _infoChip(
                      Icons
                          .stars_outlined,
                      '${item.rewardPoints} Points',
                    ),
                    _infoChip(
                      Icons
                          .bolt_outlined,
                      '${item.rewardXp} XP',
                    ),
                    _infoChip(
                      Icons
                          .military_tech_outlined,
                      item.badgeName
                          .isEmpty
                          ? 'No Badge'
                          : item.badgeName,
                    ),
                    _infoChip(
                      Icons
                          .flag_outlined,
                      '${item.targetValue} ${item.unit}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(
            width:
            16,
          ),

          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal:
              12,
              vertical:
              6,
            ),
            decoration:
            BoxDecoration(
              color: item.isActive
                  ? Colors.green
                  .shade50
                  : Colors.grey
                  .shade200,
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
            child: Text(
              item.isActive
                  ? 'Active'
                  : 'Inactive',
              style:
              TextStyle(
                color: item.isActive
                    ? Colors.green
                    .shade800
                    : Colors.grey
                    .shade700,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(
            width:
            12,
          ),

          IconButton(
            tooltip:
            'Edit',
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                _openEditChallengeDialog(
                  item,
                );
              });
            },
            icon:
            const Icon(
              Icons.edit_outlined,
            ),
          ),

          IconButton(
            tooltip:
            'Delete',
            color:
            Colors.red,
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                _deleteChallenge(
                  item,
                );
              });
            },
            icon:
            const Icon(
              Icons.delete_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeImagePlaceholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 38,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _infoChip(
      IconData icon,
      String text,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Icon(
          icon,
          size:
          16,
          color:
          mainGreen,
        ),
        const SizedBox(
          width:
          4,
        ),
        Text(
          text,
          style:
          TextStyle(
            fontSize:
            12,
            color:
            Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _label(
      String text,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom:
        6,
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration
  _inputDecoration(
      String hint,
      ) {
    return InputDecoration(
      hintText:
      hint.isEmpty
          ? null
          : hint,
      isDense:
      true,
      filled:
      true,
      fillColor:
      Colors.white,
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          9,
        ),
        borderSide:
        BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          9,
        ),
        borderSide:
        BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          9,
        ),
        borderSide:
        const BorderSide(
          color:
          mainGreen,
        ),
      ),
    );
  }
}

// ============================================================
// INTERNAL MODELS
// ============================================================

class _AdminChallengeRecord {
  const _AdminChallengeRecord({
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
    required this.startAt,
    required this.endAt,
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
  final List<String>
  requiredAttractionIds;
  final bool isActive;
  final int displayOrder;
  final String unit;
  final String badgeName;
  final String badgeDescription;
  final String badgeImageUrl;
  final DateTime? startAt;
  final DateTime? endAt;
}

class _AttractionOption {
  const _AttractionOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
