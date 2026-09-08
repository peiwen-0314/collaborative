import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/attraction.dart';
import '../services/attraction_reviews_service.dart';
import '../services/review_moderation_service.dart';
import '../services/review_photo_service.dart';

class WriteAttractionReviewPage
    extends StatefulWidget {
  const WriteAttractionReviewPage({
    super.key,
    required this.attraction,
  });

  final AttractionModel attraction;

  @override
  State<WriteAttractionReviewPage>
  createState() =>
      _WriteAttractionReviewPageState();
}

class _WriteAttractionReviewPageState
    extends State<
        WriteAttractionReviewPage> {
  static const Color mainGreen =
  Color(0xFF2E7D32);

  static const Color lightGreen =
  Color(0xFFE8F5E9);

  static const Color pageBackground =
  Color(0xFFF8FAF8);

  static const Color secondaryText =
  Color(0xFF777777);

  static const int maxPhotos = 5;

  final TextEditingController
  _reviewController =
  TextEditingController();

  final ImagePicker _picker =
  ImagePicker();

  final List<XFile> _photos =
  <XFile>[];

  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      pageBackground,
      appBar: AppBar(
        backgroundColor:
        Colors.white,
        surfaceTintColor:
        Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            size: 19,
          ),
        ),
        title: const Text(
          'Write a Review',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets
              .fromLTRB(
            16,
            14,
            16,
            28,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              _attractionCard(),

              const SizedBox(
                height: 18,
              ),

              const Text(
                'Your Rating',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                  FontWeight
                      .w700,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              const Text(
                'How was your experience?',
                style: TextStyle(
                  fontSize: 9,
                  color:
                  secondaryText,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Row(
                children:
                List.generate(
                  5,
                      (index) {
                    final star =
                        index + 1;

                    return IconButton(
                      padding:
                      EdgeInsets
                          .zero,
                      constraints:
                      const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      onPressed: () {
                        setState(() {
                          _rating =
                              star;
                        });
                      },
                      icon: Icon(
                        star <= _rating
                            ? Icons
                            .star_rounded
                            : Icons
                            .star_border_rounded,
                        size: 31,
                        color:
                        const Color(
                          0xFFFFB300,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              const Text(
                'Your Review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                  FontWeight
                      .w700,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              const Text(
                'Share useful details about your visit.',
                style: TextStyle(
                  fontSize: 9,
                  color:
                  secondaryText,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              TextField(
                controller:
                _reviewController,
                minLines: 5,
                maxLines: 8,
                maxLength: 800,
                textCapitalization:
                TextCapitalization
                    .sentences,
                decoration:
                InputDecoration(
                  hintText:
                  'What did you like or dislike about this attraction?',
                  hintStyle:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    Color(
                      0xFFAAAAAA,
                    ),
                  ),
                  filled: true,
                  fillColor:
                  Colors.white,
                  contentPadding:
                  const EdgeInsets
                      .all(
                    13,
                  ),
                  enabledBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                    borderSide:
                    const BorderSide(
                      color:
                      Color(
                        0xFFE1E5E1,
                      ),
                    ),
                  ),
                  focusedBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                    borderSide:
                    const BorderSide(
                      color:
                      mainGreen,
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              _photoSection(),

              const SizedBox(
                height: 12,
              ),

              Container(
                width:
                double.infinity,
                padding:
                const EdgeInsets
                    .all(
                  11,
                ),
                decoration:
                BoxDecoration(
                  color: lightGreen,
                  borderRadius:
                  BorderRadius
                      .circular(
                    9,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Icon(
                      Icons
                          .verified_user_outlined,
                      size: 16,
                      color:
                      mainGreen,
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: Text(
                        'Before publishing, your review text is checked for inappropriate or harmful content. Reviews that do not pass the check will not be saved.',
                        style:
                        TextStyle(
                          fontSize: 8,
                          height: 1.35,
                          color:
                          secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              SizedBox(
                width:
                double.infinity,
                height: 44,
                child:
                ElevatedButton
                    .icon(
                  onPressed:
                  _submitting
                      ? null
                      : _submitReview,
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    mainGreen,
                    foregroundColor:
                    Colors.white,
                    disabledBackgroundColor:
                    mainGreen
                        .withValues(
                      alpha: 0.55,
                    ),
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        9,
                      ),
                    ),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color:
                      Colors
                          .white,
                    ),
                  )
                      : const Icon(
                    Icons
                        .send_rounded,
                    size: 17,
                  ),
                  label: Text(
                    _submitting
                        ? 'Checking & Publishing...'
                        : 'Submit Review',
                    style:
                    const TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight
                          .w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Add Photos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_photos.length}/$maxPhotos',
              style:
              const TextStyle(
                fontSize: 9,
                color:
                secondaryText,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        const Text(
          'Optional. Add up to 5 photos from your visit.',
          style: TextStyle(
            fontSize: 9,
            color: secondaryText,
          ),
        ),

        const SizedBox(height: 9),

        SizedBox(
          height: 86,
          child:
          ListView.separated(
            scrollDirection:
            Axis.horizontal,
            itemCount:
            _photos.length +
                (_photos.length <
                    maxPhotos
                    ? 1
                    : 0),
            separatorBuilder:
                (context, index) =>
            const SizedBox(
              width: 8,
            ),
            itemBuilder:
                (context, index) {
              if (index ==
                  _photos.length) {
                return _addPhotoTile();
              }

              return _selectedPhotoTile(
                _photos[index],
                index,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _addPhotoTile() {
    return InkWell(
      onTap:
      _submitting
          ? null
          : _pickPhotos,
      borderRadius:
      BorderRadius.circular(
        9,
      ),
      child: Container(
        width: 86,
        height: 86,
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            9,
          ),
          border: Border.all(
            color:
            const Color(
              0xFFCED8CE,
            ),
          ),
        ),
        child: const Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,
          children: [
            Icon(
              Icons
                  .add_photo_alternate_outlined,
              size: 25,
              color: mainGreen,
            ),
            SizedBox(height: 5),
            Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 8,
                color: mainGreen,
                fontWeight:
                FontWeight
                    .w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedPhotoTile(
      XFile photo,
      int index,
      ) {
    return FutureBuilder<
        List<int>>(
      future: photo.readAsBytes(),
      builder:
          (context, snapshot) {
        final bytes =
            snapshot.data;

        return Stack(
          children: [
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                9,
              ),
              child: Container(
                width: 86,
                height: 86,
                color:
                lightGreen,
                child:
                bytes == null
                    ? const Center(
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                    color:
                    mainGreen,
                  ),
                )
                    : Image.memory(
                  Uint8List.fromList(
                    bytes,
                  ),
                  fit:
                  BoxFit
                      .cover,
                ),
              ),
            ),

            Positioned(
              right: 4,
              top: 4,
              child:
              Material(
                color: Colors.black
                    .withValues(
                  alpha: 0.65,
                ),
                shape:
                const CircleBorder(),
                child: InkWell(
                  customBorder:
                  const CircleBorder(),
                  onTap:
                  _submitting
                      ? null
                      : () {
                    setState(
                          () {
                        _photos
                            .removeAt(
                          index,
                        );
                      },
                    );
                  },
                  child:
                  const Padding(
                    padding:
                    EdgeInsets
                        .all(
                      3,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 13,
                      color:
                      Colors
                          .white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickPhotos() async {
    try {
      final picked =
      await _picker
          .pickMultiImage(
        imageQuality: 82,
      );

      if (picked.isEmpty ||
          !mounted) {
        return;
      }

      final available =
          maxPhotos -
              _photos.length;

      final toAdd =
      picked
          .take(available)
          .toList();

      setState(() {
        _photos.addAll(
          toAdd,
        );
      });

      if (picked.length >
          available) {
        _showMessage(
          'You can upload up to $maxPhotos photos.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to open your photo gallery.',
        isError: true,
      );
    }
  }

  Widget _attractionCard() {
    final imageUrl =
    widget.attraction
        .coverImageUrl
        .trim()
        .isNotEmpty
        ? widget.attraction
        .coverImageUrl
        .trim()
        : widget.attraction
        .imageUrls
        .isNotEmpty
        ? widget.attraction
        .imageUrls.first
        : '';

    return Container(
      padding:
      const EdgeInsets.all(
        9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          11,
        ),
        border: Border.all(
          color:
          const Color(
            0xFFE3E7E3,
          ),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              8,
            ),
            child: SizedBox(
              width: 62,
              height: 62,
              child:
              imageUrl.isEmpty
                  ? Container(
                color:
                lightGreen,
                child:
                const Icon(
                  Icons
                      .landscape_outlined,
                  color:
                  mainGreen,
                ),
              )
                  : Image.network(
                imageUrl,
                fit:
                BoxFit
                    .cover,
                errorBuilder:
                    (
                    context,
                    error,
                    stackTrace,
                    ) =>
                    Container(
                      color:
                      lightGreen,
                      child:
                      const Icon(
                        Icons
                            .landscape_outlined,
                        color:
                        mainGreen,
                      ),
                    ),
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  widget
                      .attraction
                      .name,
                  maxLines: 2,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons
                          .location_on_outlined,
                      size: 12,
                      color:
                      mainGreen,
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Expanded(
                      child: Text(
                        _location(),
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 8.5,
                          color:
                          secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _location() {
    return [
      widget.attraction.area,
      widget.attraction.state,
    ]
        .where(
          (item) =>
      item
          .trim()
          .isNotEmpty,
    )
        .join(', ');
  }

  Future<void>
  _submitReview() async {
    final text =
    _reviewController.text
        .trim();

    if (_rating == 0) {
      _showMessage(
        'Please select a star rating.',
      );
      return;
    }

    if (text.length < 5) {
      _showMessage(
        'Please write a little more about your experience.',
      );
      return;
    }

    final user =
        FirebaseAuth
            .instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login before submitting a review.',
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    List<String> uploadedUrls =
    const <String>[];

    try {
      // 1. Moderate text BEFORE uploading photos.
      final moderation =
      await ReviewModerationService
          .instance
          .moderate(
        text,
      );

      if (!mounted) {
        return;
      }

      if (!moderation.allowed) {
        final debug =
            moderation.debugCode;

        _showMessage(
          debug == null ||
              debug.isEmpty
              ? moderation.message
              : '${moderation.message} [$debug]',
          isError: true,
        );
        return;
      }

      // 2. Upload optional photos only after text passes.
      if (_photos.isNotEmpty) {
        uploadedUrls =
        await ReviewPhotoService
            .instance
            .uploadReviewPhotos(
          attractionId:
          widget
              .attraction.id,
          photos: _photos,
        );
      }

      // 3. Save Firestore review with photo URLs.
      await AttractionReviewsService
          .instance
          .addReview(
        attractionId:
        widget.attraction.id,
        authorName:
        user.displayName ??
            user.email
                ?.split('@')
                .first ??
            'User',
        rating: _rating,
        text: text,
        photoUrls:
        uploadedUrls,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      )
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor:
            mainGreen,
            content: Text(
              'Review published successfully.',
            ),
          ),
        );

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      // Clean up uploaded photos if Firestore write fails.
      if (uploadedUrls
          .isNotEmpty) {
        await ReviewPhotoService
            .instance
            .deletePhotos(
          uploadedUrls,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to submit review. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
          isError
              ? Colors
              .red
              .shade700
              : mainGreen,
          content:
          Text(message),
        ),
      );
  }
}
