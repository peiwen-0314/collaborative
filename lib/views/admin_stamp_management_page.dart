import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'admin_challenge_management_page.dart';
import 'admin_home_page.dart';
import 'admin_login_page.dart';
import 'admin_sidebar.dart';

class AdminStampManagementPage extends StatefulWidget {
  const AdminStampManagementPage({super.key});

  @override
  State<AdminStampManagementPage> createState() =>
      _AdminStampManagementPageState();
}

class _AdminStampManagementPageState
    extends State<AdminStampManagementPage> {
  static const Color mainGreen = Color(0xFF2E7D32);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';

  // ============================================================
  // WATCH HERITAGE ATTRACTIONS
  // ============================================================

  Stream<List<_StampRecord>> _watchStampRecords() {
    return _firestore
        .collection('heritage_attractions')
        .snapshots()
        .asyncMap((heritageSnapshot) async {
      final records = <_StampRecord>[];

      for (final heritageDoc in heritageSnapshot.docs) {
        final heritageData = heritageDoc.data();

        final attractionId =
        (heritageData['attractionId'] ?? '').toString().trim();

        if (attractionId.isEmpty) {
          continue;
        }

        final attractionDoc = await _firestore
            .collection('attractions')
            .doc(attractionId)
            .get();

        if (!attractionDoc.exists) {
          continue;
        }

        final attractionData =
            attractionDoc.data() ?? <String, dynamic>{};

        final attractionName =
        (attractionData['name'] ?? '').toString().trim();

        if (attractionName.isEmpty) {
          continue;
        }

        final stampImageUrl =
        (heritageData['stampImageUrl'] ?? '').toString().trim();

        String attractionImageUrl =
        (attractionData['coverImageUrl'] ?? '').toString().trim();

        if (attractionImageUrl.isEmpty) {
          final imageUrls = attractionData['imageUrls'];

          if (imageUrls is List && imageUrls.isNotEmpty) {
            attractionImageUrl =
                imageUrls.first.toString().trim();
          }
        }

        records.add(
          _StampRecord(
            heritageDocumentId: heritageDoc.id,
            attractionId: attractionId,
            attractionName: attractionName,
            attractionImageUrl: attractionImageUrl,
            stampImageUrl: stampImageUrl,
          ),
        );
      }

      records.sort(
            (a, b) => a.attractionName
            .toLowerCase()
            .compareTo(b.attractionName.toLowerCase()),
      );

      return records;
    });
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AdminLoginPage(),
      ),
          (_) => false,
    );
  }

  // ============================================================
  // UPLOAD STAMP IMAGE
  // ============================================================

  Future<String?> _pickAndUploadStampImage({
    required String attractionId,
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

      // =========================================================
      // VALIDATE FILE TYPE
      // =========================================================

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

      // =========================================================
      // VALIDATE FILE SIZE - MAX 5MB
      // =========================================================

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

      // =========================================================
      // READ FILE
      // =========================================================

      final Uint8List bytes =
      await file.readAsBytes();

      // =========================================================
      // CONTENT TYPE
      // =========================================================

      final contentType =
      extension == 'png'
          ? 'image/png'
          : 'image/jpeg';

      // =========================================================
      // FIREBASE STORAGE
      // =========================================================

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final storageRef =
      _storage.ref().child(
        'stamp_images/'
            '$attractionId/'
            'stamp_$timestamp.$extension',
      );

      final metadata =
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'type': 'heritage_stamp',
          'attractionId': attractionId,
        },
      );

      final snapshot =
      await storageRef.putData(
        bytes,
        metadata,
      );

      final downloadUrl =
      await snapshot.ref
          .getDownloadURL();

      return downloadUrl;
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
  // GENERATE STAMP IMAGE
  // ============================================================

  Future<String?> _generateStampImage({
    required String attractionId,
    required String attractionName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage(
          'Please sign in again.',
        );
        return null;
      }

      // Get Firebase Auth ID token
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
          'generateStampImage';

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
            'attractionId':
            attractionId,
            'attractionName':
            attractionName,
          },
        }),
      );

      debugPrint(
        'Generate Stamp HTTP status: '
            '${response.statusCode}',
      );

      debugPrint(
        'Generate Stamp response: '
            '${response.body}',
      );

      final dynamic decoded =
      jsonDecode(response.body);

      if (decoded is! Map) {
        _showMessage(
          'Invalid server response.',
        );
        return null;
      }

      final data =
      Map<String, dynamic>.from(
        decoded,
      );

      // Callable function returned an error
      if (data['error'] != null) {
        final error =
        data['error'];

        String message =
            'Unable to generate image.';

        if (error is Map &&
            error['message'] != null) {
          message =
              error['message']
                  .toString();
        }

        _showMessage(
          'Generate failed: $message',
        );

        return null;
      }

      // Callable response normally comes under "result"
      final result =
      data['result'];

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
          'AI did not return an image.',
        );
        return null;
      }

      return imageUrl;
    } catch (e, stackTrace) {
      debugPrint(
        'Generate stamp error: $e',
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
  // CREATE NEW STAMP
  // ============================================================

  Future<void> _openCreateStampDialog(
      List<_StampRecord> allRecords,
      ) async {
    final availableRecords = allRecords
        .where(
          (record) =>
      record.stampImageUrl.isEmpty,
    )
        .toList();

    if (availableRecords.isEmpty) {
      _showMessage(
        'All heritage attractions already have stamps.',
      );
      return;
    }

    final attractionSearchController =
    TextEditingController();

    _StampRecord? selectedRecord;

    String attractionSearch = '';
    String previewUrl = '';

    bool isUploading = false;
    bool isGenerating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredAttractions =
            availableRecords.where(
                  (record) {
                if (attractionSearch.isEmpty) {
                  return true;
                }

                return record.attractionName
                    .toLowerCase()
                    .contains(
                  attractionSearch
                      .toLowerCase(),
                );
              },
            ).toList();

            final busy =
                isUploading ||
                    isGenerating;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(18),
              ),
              title: const Text(
                'Create New Stamp',
              ),
              content: SizedBox(
                width: 1000,
                height: 650,
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // LEFT SIDE
                    // ==================================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Attraction',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller:
                            attractionSearchController,
                            onChanged: (value) {
                              setDialogState(() {
                                attractionSearch =
                                    value.trim();
                              });
                            },
                            decoration:
                            _inputDecoration(
                              'Search current attraction...',
                            ).copyWith(
                              prefixIcon:
                              const Icon(
                                Icons.search,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            height: 190,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                const Color(
                                  0xFFDDE2DD,
                                ),
                              ),
                              borderRadius:
                              BorderRadius.circular(
                                10,
                              ),
                            ),
                            child: filteredAttractions
                                .isEmpty
                                ? const Center(
                              child: Text(
                                'No available attractions found.',
                              ),
                            )
                                : ListView.separated(
                              itemCount:
                              filteredAttractions
                                  .length,
                              separatorBuilder:
                                  (_, __) =>
                              const Divider(
                                height: 1,
                              ),
                              itemBuilder:
                                  (context, index) {
                                final record =
                                filteredAttractions[
                                index];

                                final selected =
                                    selectedRecord
                                        ?.heritageDocumentId ==
                                        record
                                            .heritageDocumentId;

                                return Material(
                                  color: selected
                                      ? const Color(
                                    0xFFE8F5E9,
                                  )
                                      : Colors
                                      .transparent,
                                  child: InkWell(
                                    onTap:
                                    busy
                                        ? null
                                        : () {
                                      setDialogState(
                                            () {
                                          selectedRecord =
                                              record;

                                          // Selecting another attraction
                                          // resets current preview.
                                          previewUrl =
                                          '';
                                        },
                                      );
                                    },
                                    child: Padding(
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                        horizontal:
                                        12,
                                        vertical:
                                        10,
                                      ),
                                      child: Row(
                                        children: [
                                          _attractionThumbnail(
                                            record,
                                          ),

                                          const SizedBox(
                                            width: 12,
                                          ),

                                          Expanded(
                                            child: Text(
                                              record
                                                  .attractionName,
                                              style:
                                              TextStyle(
                                                fontWeight:
                                                selected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),

                                          if (selected)
                                            const Icon(
                                              Icons
                                                  .check_circle,
                                              color:
                                              mainGreen,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Selected Attraction',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.all(
                              14,
                            ),
                            decoration: BoxDecoration(
                              color:
                              const Color(
                                0xFFF5F7F5,
                              ),
                              borderRadius:
                              BorderRadius.circular(
                                10,
                              ),
                              border: Border.all(
                                color:
                                const Color(
                                  0xFFDDE2DD,
                                ),
                              ),
                            ),
                            child: Text(
                              selectedRecord == null
                                  ? 'No attraction selected'
                                  : selectedRecord!
                                  .attractionName,
                              style: TextStyle(
                                color:
                                selectedRecord ==
                                    null
                                    ? Colors.grey
                                    : Colors
                                    .black87,
                                fontWeight:
                                selectedRecord ==
                                    null
                                    ? FontWeight
                                    .normal
                                    : FontWeight
                                    .w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Stamp Image',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child:
                                OutlinedButton.icon(
                                  onPressed:
                                  selectedRecord ==
                                      null ||
                                      busy
                                      ? null
                                      : () async {
                                    setDialogState(
                                          () {
                                        isUploading =
                                        true;
                                      },
                                    );

                                    final uploadedUrl =
                                    await _pickAndUploadStampImage(
                                      attractionId:
                                      selectedRecord!
                                          .attractionId,
                                    );

                                    if (!dialogContext
                                        .mounted) {
                                      return;
                                    }

                                    setDialogState(
                                          () {
                                        isUploading =
                                        false;

                                        if (uploadedUrl !=
                                            null) {
                                          previewUrl =
                                              uploadedUrl;
                                        }
                                      },
                                    );
                                  },
                                  icon: isUploading
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth:
                                      2,
                                    ),
                                  )
                                      : const Icon(
                                    Icons
                                        .upload_file,
                                  ),
                                  label: Text(
                                    isUploading
                                        ? 'Uploading...'
                                        : 'Upload Image',
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child:
                                OutlinedButton.icon(
                                  onPressed:
                                  selectedRecord ==
                                      null ||
                                      busy
                                      ? null
                                      : () async {
                                    setDialogState(
                                          () {
                                        isGenerating =
                                        true;
                                      },
                                    );

                                    final generatedUrl =
                                    await _generateStampImage(
                                      attractionId:
                                      selectedRecord!
                                          .attractionId,
                                      attractionName:
                                      selectedRecord!
                                          .attractionName,
                                    );

                                    if (!dialogContext
                                        .mounted) {
                                      return;
                                    }

                                    setDialogState(
                                          () {
                                        isGenerating =
                                        false;

                                        if (generatedUrl !=
                                            null) {
                                          previewUrl =
                                              generatedUrl;
                                        }
                                      },
                                    );
                                  },
                                  icon: isGenerating
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth:
                                      2,
                                    ),
                                  )
                                      : const Icon(
                                    Icons
                                        .auto_awesome,
                                  ),
                                  label: Text(
                                    isGenerating
                                        ? 'Generating...'
                                        : 'Generate Image',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Supported: JPG, JPEG, PNG • Maximum 5 MB • 1 image only',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                              Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 30),

                    // ==================================================
                    // RIGHT PREVIEW
                    // ==================================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stamp Preview',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Container(
                            height: 380,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                              const Color(
                                0xFFF7F8F7,
                              ),
                              borderRadius:
                              BorderRadius.circular(
                                14,
                              ),
                              border: Border.all(
                                color:
                                const Color(
                                  0xFFE0E4E0,
                                ),
                              ),
                            ),
                            child: previewUrl.isEmpty
                                ? const Column(
                              mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                              children: [
                                Icon(
                                  Icons
                                      .card_giftcard_outlined,
                                  size: 72,
                                  color:
                                  Colors.grey,
                                ),
                                SizedBox(
                                  height: 12,
                                ),
                                Text(
                                  'No stamp image selected',
                                  style:
                                  TextStyle(
                                    color:
                                    Colors.grey,
                                  ),
                                ),
                              ],
                            )
                                : Stack(
                              children: [
                                Positioned.fill(
                                  child:
                                  ClipRRect(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      14,
                                    ),
                                    child:
                                    Image.network(
                                      previewUrl,
                                      fit:
                                      BoxFit.contain,
                                      errorBuilder:
                                          (_, __, ___) {
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

                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child:
                                  Material(
                                    color:
                                    Colors.white,
                                    shape:
                                    const CircleBorder(),
                                    elevation: 2,
                                    child:
                                    IconButton(
                                      tooltip:
                                      'Remove image',
                                      onPressed:
                                      busy
                                          ? null
                                          : () {
                                        setDialogState(
                                              () {
                                            previewUrl =
                                            '';
                                          },
                                        );
                                      },
                                      icon:
                                      const Icon(
                                        Icons.close,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (selectedRecord !=
                              null) ...[
                            const SizedBox(
                              height: 18,
                            ),

                            const Text(
                              'Stamp Name',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                Colors.grey,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              '${selectedRecord!.attractionName} Stamp',
                              style:
                              const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                    if (selectedRecord ==
                        null) {
                      _showMessage(
                        'Please select an attraction.',
                      );
                      return;
                    }

                    if (previewUrl.isEmpty) {
                      _showMessage(
                        'Please upload or generate a stamp image.',
                      );
                      return;
                    }

                    await _firestore
                        .collection(
                      'heritage_attractions',
                    )
                        .doc(
                      selectedRecord!
                          .heritageDocumentId,
                    )
                        .update({
                      'stampImageUrl':
                      previewUrl,
                      'lastUpdated':
                      FieldValue
                          .serverTimestamp(),
                    });

                    if (!dialogContext
                        .mounted) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    _showMessage(
                      'Stamp created successfully.',
                    );
                  },
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    mainGreen,
                    foregroundColor:
                    Colors.white,
                  ),
                  child:
                  const Text(
                    'Create Stamp',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    attractionSearchController
        .dispose();
  }

  // ============================================================
  // EDIT EXISTING STAMP
  // ============================================================

  Future<void> _openEditStampDialog(
      _StampRecord record,
      ) async {
    String previewUrl =
        record.stampImageUrl;

    bool isUploading = false;
    bool isGenerating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final busy =
                isUploading ||
                    isGenerating;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  18,
                ),
              ),
              title:
              const Text('Edit Stamp'),
              content: SizedBox(
                width: 780,
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize:
                        MainAxisSize.min,
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attraction',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.all(
                              14,
                            ),
                            decoration: BoxDecoration(
                              color:
                              const Color(
                                0xFFF5F7F5,
                              ),
                              borderRadius:
                              BorderRadius.circular(
                                10,
                              ),
                            ),
                            child: Text(
                              record
                                  .attractionName,
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Replace Stamp Image',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child:
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                    setDialogState(
                                          () {
                                        isUploading =
                                        true;
                                      },
                                    );

                                    final uploadedUrl =
                                    await _pickAndUploadStampImage(
                                      attractionId:
                                      record
                                          .attractionId,
                                    );

                                    if (!dialogContext
                                        .mounted) {
                                      return;
                                    }

                                    setDialogState(
                                          () {
                                        isUploading =
                                        false;

                                        if (uploadedUrl !=
                                            null) {
                                          previewUrl =
                                              uploadedUrl;
                                        }
                                      },
                                    );
                                  },
                                  icon: isUploading
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth:
                                      2,
                                    ),
                                  )
                                      : const Icon(
                                    Icons
                                        .upload_file,
                                  ),
                                  label: Text(
                                    isUploading
                                        ? 'Uploading...'
                                        : 'Upload Image',
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child:
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                    setDialogState(
                                          () {
                                        isGenerating =
                                        true;
                                      },
                                    );

                                    final generatedUrl =
                                    await _generateStampImage(
                                      attractionId:
                                      record
                                          .attractionId,
                                      attractionName:
                                      record
                                          .attractionName,
                                    );

                                    if (!dialogContext
                                        .mounted) {
                                      return;
                                    }

                                    setDialogState(
                                          () {
                                        isGenerating =
                                        false;

                                        if (generatedUrl !=
                                            null) {
                                          previewUrl =
                                              generatedUrl;
                                        }
                                      },
                                    );
                                  },
                                  icon: isGenerating
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth:
                                      2,
                                    ),
                                  )
                                      : const Icon(
                                    Icons
                                        .auto_awesome,
                                  ),
                                  label: Text(
                                    isGenerating
                                        ? 'Generating...'
                                        : 'Generate Image',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Supported: JPG, JPEG, PNG • Maximum 5 MB • 1 image only',
                            style:
                            TextStyle(
                              fontSize: 12,
                              color:
                              Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 28),

                    Expanded(
                      child: Container(
                        height: 300,
                        decoration:
                        BoxDecoration(
                          color:
                          const Color(
                            0xFFF7F8F7,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                          border: Border.all(
                            color:
                            const Color(
                              0xFFE0E4E0,
                            ),
                          ),
                        ),
                        child: previewUrl.isEmpty
                            ? const Icon(
                          Icons
                              .card_giftcard_outlined,
                          size: 72,
                          color:
                          Colors.grey,
                        )
                            : ClipRRect(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                          child:
                          Image.network(
                            previewUrl,
                            fit:
                            BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) {
                              return const Center(
                                child: Text(
                                  'Unable to load image',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                    if (previewUrl.isEmpty) {
                      _showMessage(
                        'Please upload or generate a stamp image.',
                      );
                      return;
                    }

                    await _firestore
                        .collection(
                      'heritage_attractions',
                    )
                        .doc(
                      record
                          .heritageDocumentId,
                    )
                        .update({
                      'stampImageUrl':
                      previewUrl,
                      'lastUpdated':
                      FieldValue
                          .serverTimestamp(),
                    });

                    if (!dialogContext
                        .mounted) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    _showMessage(
                      'Stamp updated successfully.',
                    );
                  },
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    mainGreen,
                    foregroundColor:
                    Colors.white,
                  ),
                  child:
                  const Text(
                    'Save Changes',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // REMOVE STAMP
  // ============================================================

  Future<void> _removeStamp(
      _StampRecord record,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text('Remove Stamp'),
          content: Text(
            'Remove ${record.attractionName} Stamp?\n\n'
                'The attraction itself will not be deleted.',
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
              const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.red,
                foregroundColor:
                Colors.white,
              ),
              child:
              const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _firestore
        .collection(
      'heritage_attractions',
    )
        .doc(
      record.heritageDocumentId,
    )
        .update({
      'stampImageUrl': '',
      'lastUpdated':
      FieldValue.serverTimestamp(),
    });

    _showMessage(
      'Stamp removed successfully.',
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _attractionThumbnail(
      _StampRecord record,
      ) {
    if (record.attractionImageUrl.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
          const Color(
            0xFFE8F5E9,
          ),
          borderRadius:
          BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.place_outlined,
          color: mainGreen,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(8),
      child: Image.network(
        record.attractionImageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return Container(
            width: 48,
            height: 48,
            color:
            const Color(
              0xFFE8F5E9,
            ),
            child: const Icon(
              Icons.place_outlined,
              color: mainGreen,
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(
      String hint,
      ) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(10),
        borderSide:
        const BorderSide(
          color:
          Color(
            0xFFD9DED9,
          ),
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(10),
        borderSide:
        const BorderSide(
          color:
          Color(
            0xFFD9DED9,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(
        0xFFF5F7F5,
      ),
      body: Row(
        children: [
          AdminSidebar(
            selectedPage: 'stamp',

            onDashboardTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AdminHomePage(),
                ),
              );
            },

            onAttractionTap: () {},
            onCategoryTap: () {},
            onCulturalHeritageTap: () {},
            onModerationTap: () {},

            onStampTap: () {},

            onChallengeTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const AdminChallengeManagementPage(),
                ),
              );
            },

            onReportTap: () {},
            onLogoutTap: _logout,
          ),

          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.all(
                32,
              ),
              child: StreamBuilder<
                  List<_StampRecord>>(
                stream:
                _watchStampRecords(),
                builder:
                    (context, snapshot) {
                  if (snapshot
                      .connectionState ==
                      ConnectionState
                          .waiting) {
                    return const Center(
                      child:
                      CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load stamps.\n'
                            '${snapshot.error}',
                      ),
                    );
                  }

                  final allRecords =
                      snapshot.data ?? [];

                  final existingStamps =
                  allRecords
                      .where(
                        (record) =>
                    record
                        .stampImageUrl
                        .isNotEmpty,
                  )
                      .where(
                        (record) =>
                    _searchText
                        .isEmpty ||
                        record
                            .attractionName
                            .toLowerCase()
                            .contains(
                          _searchText,
                        ),
                  )
                      .toList();

                  final availableCount =
                      allRecords
                          .where(
                            (record) =>
                        record
                            .stampImageUrl
                            .isEmpty,
                      )
                          .length;

                  return Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              const Text(
                                'Stamp Management',
                                style:
                                TextStyle(
                                  fontSize: 28,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                '${existingStamps.length} existing stamps • '
                                    '$availableCount attractions available',
                                style:
                                const TextStyle(
                                  color:
                                  Colors.grey,
                                ),
                              ),
                            ],
                          ),

                          ElevatedButton.icon(
                            onPressed:
                            availableCount ==
                                0
                                ? null
                                : () {
                              _openCreateStampDialog(
                                allRecords,
                              );
                            },
                            icon:
                            const Icon(
                              Icons.add,
                            ),
                            label:
                            const Text(
                              'Create New Stamp',
                            ),
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
                                horizontal:
                                20,
                                vertical:
                                16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      Container(
                        padding:
                        const EdgeInsets
                            .all(
                          18,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.white,
                          borderRadius:
                          BorderRadius
                              .circular(
                            15,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child:
                              TextField(
                                controller:
                                _searchController,
                                onChanged:
                                    (value) {
                                  setState(() {
                                    _searchText =
                                        value
                                            .trim()
                                            .toLowerCase();
                                  });
                                },
                                decoration:
                                _inputDecoration(
                                  'Search existing stamps...',
                                ).copyWith(
                                  prefixIcon:
                                  const Icon(
                                    Icons
                                        .search,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 14,
                            ),

                            OutlinedButton.icon(
                              onPressed: () {
                                _searchController
                                    .clear();

                                setState(() {
                                  _searchText =
                                  '';
                                });
                              },
                              icon:
                              const Icon(
                                Icons.refresh,
                              ),
                              label:
                              const Text(
                                'Reset',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      Expanded(
                        child: Container(
                          decoration:
                          BoxDecoration(
                            color:
                            Colors.white,
                            borderRadius:
                            BorderRadius
                                .circular(
                              15,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal:
                                  24,
                                  vertical:
                                  18,
                                ),
                                decoration:
                                const BoxDecoration(
                                  color:
                                  Color(
                                    0xFFF8F9F8,
                                  ),
                                  borderRadius:
                                  BorderRadius
                                      .vertical(
                                    top:
                                    Radius.circular(
                                      15,
                                    ),
                                  ),
                                ),
                                child:
                                const Row(
                                  children: [
                                    SizedBox(
                                      width:
                                      100,
                                      child:
                                      Text(
                                        'Stamp',
                                        style:
                                        TextStyle(
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    Expanded(
                                      flex: 3,
                                      child:
                                      Text(
                                        'Attraction',
                                        style:
                                        TextStyle(
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    Expanded(
                                      flex: 3,
                                      child:
                                      Text(
                                        'Stamp Name',
                                        style:
                                        TextStyle(
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    SizedBox(
                                      width:
                                      120,
                                      child:
                                      Text(
                                        'Actions',
                                        style:
                                        TextStyle(
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (existingStamps
                                  .isEmpty)
                                const Expanded(
                                  child:
                                  Center(
                                    child: Text(
                                      'No existing stamps found.',
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child:
                                  ListView
                                      .separated(
                                    itemCount:
                                    existingStamps
                                        .length,
                                    separatorBuilder:
                                        (_, __) =>
                                    const Divider(
                                      height: 1,
                                    ),
                                    itemBuilder:
                                        (context,
                                        index) {
                                      return _stampRow(
                                        existingStamps[
                                        index],
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXISTING STAMP ROW
  // ============================================================

  Widget _stampRow(
      _StampRecord record,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Align(
              alignment:
              Alignment.centerLeft,
              child: Container(
                width: 60,
                height: 60,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFE8F5E9,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                  child: Image.network(
                    record.stampImageUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) {
                      return const Icon(
                        Icons
                            .card_giftcard_outlined,
                        color:
                        mainGreen,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              record.attractionName,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              '${record.attractionName} Stamp',
            ),
          ),

          SizedBox(
            width: 120,
            child: Row(
              children: [
                IconButton(
                  tooltip:
                  'Edit Stamp',
                  onPressed: () {
                    _openEditStampDialog(
                      record,
                    );
                  },
                  icon:
                  const Icon(
                    Icons.edit_outlined,
                    color:
                    mainGreen,
                  ),
                ),

                IconButton(
                  tooltip:
                  'Remove Stamp',
                  onPressed: () {
                    _removeStamp(
                      record,
                    );
                  },
                  icon:
                  const Icon(
                    Icons
                        .delete_outline,
                    color:
                    Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ============================================================
// INTERNAL DATA RECORD
// ============================================================

class _StampRecord {
  const _StampRecord({
    required this.heritageDocumentId,
    required this.attractionId,
    required this.attractionName,
    required this.attractionImageUrl,
    required this.stampImageUrl,
  });

  final String heritageDocumentId;
  final String attractionId;
  final String attractionName;
  final String attractionImageUrl;
  final String stampImageUrl;
}