import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../models/heritage_attraction.dart';
import '../services/heritage_recognition_service.dart';
import '../services/heritage_storage_service.dart';
import '../widgets/heritage_image.dart';
import 'heritage_detail_page.dart';
import 'recognition_history_page.dart';

class AiAttractionRecognitionPage extends StatefulWidget {
  const AiAttractionRecognitionPage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<AiAttractionRecognitionPage> createState() =>
      _AiAttractionRecognitionPageState();
}

class _AiAttractionRecognitionPageState
    extends State<AiAttractionRecognitionPage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color paleGreen = Color(0xFFE7F5E5);
  static const Color borderColor = Color(0xFFE1E1E1);

  final ImagePicker _picker = ImagePicker();

  final HeritageRecognitionService _recognition =
  HeritageRecognitionService();

  final HeritageStorageService _storage =
  HeritageStorageService();

  XFile? _image;

  HeritageAttraction? _attraction;

  List<String> _candidates = const [];

  List<RecognitionHistoryEntry> _history = const [];

  bool _loading = false;

  bool _historyLoading = true;

  String? _message;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ============================================================
  // LOAD RECOGNITION HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    final entries =
    await _storage.loadRecognitionHistory();

    if (!mounted) return;

    setState(() {
      _history = entries;
      _historyLoading = false;
    });
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pick(ImageSource source) async {
    final selected = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (selected == null || !mounted) {
      return;
    }

    final croppedImage = await ImageCropper().cropImage(
      sourcePath: selected.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Select Attraction Area',
          toolbarColor: green,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: green,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Select Attraction Area',
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (croppedImage == null || !mounted) {
      return;
    }

    setState(() {
      _image = XFile(croppedImage.path);
      _attraction = null;
      _candidates = const [];
      _message = null;
    });

    await _recognize();
  }

  // ============================================================
  // GOOGLE VISION RECOGNITION
  // ============================================================

  Future<void> _recognize() async {
    if (_image == null) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await _recognition.recognize(
        File(_image!.path),
      );

      if (!mounted) return;

      setState(() {
        _candidates = result.candidates;
        _attraction = result.attraction;

        _message = result.attraction == null
            ? 'The landmark was recognised, but it is not currently '
            'available in EcoTravel.'
            : null;
      });

      if (result.attraction != null) {
        // Save recognition history.
        await _storage.addRecognition(
          result.attraction!,
        );

        // Refresh history cards.
        await _loadHistory();
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message =
        'Unable to recognise this attraction.\n\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // ADD TO TRAVEL JOURNEY
  // ============================================================

  Future<void> _addToJourney() async {
    final attraction = _attraction;

    if (attraction == null) return;

    await _storage.addToDiary(attraction);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: green,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '${attraction.name} added to your Travel Journey.',
        ),
      ),
    );
  }

  // ============================================================
  // OPEN HERITAGE DETAIL
  // ============================================================

  void _openDetails(
      HeritageAttraction attraction,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HeritageDetailPage(
          attraction: attraction,
        ),
      ),
    );
  }

  // ============================================================
  // OPEN ALL HISTORY
  // ============================================================

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const RecognitionHistoryPage(),
      ),
    ).then((_) {
      _loadHistory();
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final page = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        17,
        15,
        17,
        30,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 10),

          _buildCameraArea(),

          const SizedBox(height: 15),

          if (_loading)
            _buildLoadingCard()
          else if (_attraction != null)
            _buildRecognitionResult(
              _attraction!,
            )
          else if (_message != null)
              _buildErrorCard()
            else
              _buildInstructionCard(),

          const SizedBox(height: 20),

          _buildHistorySection(),
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(
        color: Colors.white,
        child: page,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: page,
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        if (!widget.embedded)
          Padding(
            padding:
            const EdgeInsets.only(
              right: 7,
            ),
            child: InkWell(
              borderRadius:
              BorderRadius.circular(20),
              onTap: () =>
                  Navigator.maybePop(context),
              child: const Padding(
                padding:
                EdgeInsets.all(3),
                child: Icon(
                  Icons.chevron_left,
                  size: 26,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

        const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'AI Attraction Recognition',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Scan, discover, learn and travel sustainably.',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CAMERA / IMAGE AREA
  // ============================================================

  Widget _buildCameraArea() {
    return Container(
      width: double.infinity,
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius:
        BorderRadius.circular(15),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Selected image.
          if (_image != null)
            Image.file(
              File(_image!.path),
              fit: BoxFit.cover,
            )
          else
            const Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance,
                  color: green,
                  size: 54,
                ),
                SizedBox(height: 8),
                Text(
                  'Capture or select a heritage attraction',
                  style: TextStyle(
                    color: green,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),

          // Gallery button.
          Positioned(
            left: 10,
            bottom: 10,
            child: Material(
              color: Colors.black87,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder:
                const CircleBorder(),
                onTap: () =>
                    _pick(
                      ImageSource.gallery,
                    ),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons
                        .photo_library_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),

          // Camera button.
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: Material(
                color: Colors.transparent,
                shape:
                const CircleBorder(),
                child: InkWell(
                  customBorder:
                  const CircleBorder(),
                  onTap: () =>
                      _pick(
                        ImageSource.camera,
                      ),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration:
                    BoxDecoration(
                      color: Colors.white,
                      shape:
                      BoxShape.circle,
                      border: Border.all(
                        color: green,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color:
                          Color(
                            0x22000000,
                          ),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: green,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING CARD
  // ============================================================

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 25,
            height: 25,
            child:
            CircularProgressIndicator(
              color: green,
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Recognising attraction...',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECOGNITION RESULT
  // ============================================================

  Widget _buildRecognitionResult(
      HeritageAttraction attraction,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // Attraction image
              ClipRRect(
                borderRadius:
                BorderRadius.circular(8),
                child: HeritageImage(
                  imageUrl:
                  attraction.imageUrl,
                  width: 72,
                  height: 94,
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // Recognition badge
                    Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration:
                      BoxDecoration(
                        color: paleGreen,
                        borderRadius:
                        BorderRadius
                            .circular(5),
                      ),
                      child: const Row(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          Icon(
                            Icons
                                .auto_awesome,
                            color: green,
                            size: 9,
                          ),
                          SizedBox(
                            width: 3,
                          ),
                          Text(
                            'Recognition Result',
                            style:
                            TextStyle(
                              color: green,
                              fontSize: 6.5,
                              fontWeight:
                              FontWeight
                                  .w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      attraction.name,
                      maxLines: 2,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style: const TextStyle(
                        color:
                        Colors.black87,
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .location_on_outlined,
                          size: 10,
                          color:
                          Colors.black45,
                        ),
                        const SizedBox(
                          width: 2,
                        ),
                        Expanded(
                          child: Text(
                            _locationText(
                              attraction,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              color:
                              Colors
                                  .black45,
                              fontSize: 6.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      attraction
                          .shortDescription,
                      maxLines: 3,
                      overflow:
                      TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:
                        Colors.black54,
                        fontSize: 6.8,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Align(
                      alignment:
                      Alignment.centerRight,
                      child: InkWell(
                        onTap: () =>
                            _openDetails(
                              attraction,
                            ),
                        child: const Text(
                          'Learn More >',
                          style: TextStyle(
                            color: green,
                            fontSize: 6.5,
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
            ],
          ),

          const SizedBox(height: 9),

          // Sustainability / time section
          Container(
            padding:
            const EdgeInsets.symmetric(
              vertical: 7,
              horizontal: 6,
            ),
            decoration: BoxDecoration(
              color: paleGreen,
              borderRadius:
              BorderRadius.circular(7),
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _infoItem(
                    icon:
                    Icons.eco_outlined,
                    title:
                    'Sustainability Tips',
                    value: attraction
                        .sustainabilityTip,
                  ),
                ),

                _divider(),

                Expanded(
                  child: _infoItem(
                    icon: Icons
                        .schedule_outlined,
                    title:
                    'Recommended Time',
                    value: attraction
                        .recommendedTime,
                  ),
                ),

                _divider(),

                Expanded(
                  child: _infoItem(
                    icon: Icons
                        .wb_sunny_outlined,
                    title:
                    'Best Time to Visit',
                    value:
                    attraction.bestTime,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 9),

          // Add to travel journey.
          SizedBox(
            width: double.infinity,
            height: 28,
            child: OutlinedButton(
              style:
              OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: green,
                ),
                foregroundColor: green,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    6,
                  ),
                ),
                padding: EdgeInsets.zero,
              ),
              onPressed: _addToJourney,
              child: const Text(
                'Add To Travel Journey',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: green,
          size: 14,
        ),

        const SizedBox(width: 4),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                style: const TextStyle(
                  color: green,
                  fontSize: 6.3,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 5.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 29,
      margin:
      const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      color: const Color(
        0xFFCFE3CC,
      ),
    );
  }

  // ============================================================
  // HISTORY SECTION
  // ============================================================

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your Recognition History',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),

            InkWell(
              onTap: _openHistory,
              child: const Padding(
                padding:
                EdgeInsets.symmetric(
                  vertical: 5,
                ),
                child: Text(
                  'View All >',
                  style: TextStyle(
                    color: green,
                    fontSize: 8,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (_historyLoading)
          const SizedBox(
            height: 75,
            child: Center(
              child:
              CircularProgressIndicator(
                color: green,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
              ),
              borderRadius:
              BorderRadius.circular(8),
            ),
            child: const Text(
              'No recognition history yet.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 8,
              ),
            ),
          )
        else
          Row(
            children: List.generate(
              _history.length > 2
                  ? 2
                  : _history.length,
                  (index) {
                return Expanded(
                  child: Padding(
                    padding:
                    EdgeInsets.only(
                      right:
                      index == 0 &&
                          _history
                              .length >
                              1
                          ? 7
                          : 0,
                    ),
                    child:
                    _historyCard(
                      _history[index],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget _historyCard(
      RecognitionHistoryEntry entry,
      ) {
    final attraction =
        entry.attraction;

    return InkWell(
      borderRadius:
      BorderRadius.circular(7),
      onTap: () =>
          _openDetails(attraction),
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(7),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
              BorderRadius.circular(5),
              child: HeritageImage(
                imageUrl:
                attraction.imageUrl,
                width: 38,
                height: 60,
              ),
            ),

            const SizedBox(width: 6),

            Expanded(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    attraction.name,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style: const TextStyle(
                      color:
                      Colors.black87,
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    attraction.locationText,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style: const TextStyle(
                      color:
                      Colors.black45,
                      fontSize: 7,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    _formatHistoryDate(
                      entry.recognizedAt,
                    ),
                    style:
                    const TextStyle(
                      color:
                      Colors.black45,
                      fontSize: 6,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration:
                    BoxDecoration(
                      color: paleGreen,
                      borderRadius:
                      BorderRadius
                          .circular(4),
                    ),
                    child: const Text(
                      'Saved',
                      style:
                      TextStyle(
                        color: green,
                        fontSize: 4.8,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INSTRUCTION
  // ============================================================

  Widget _buildInstructionCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF8FAF7,
        ),
        borderRadius:
        BorderRadius.circular(9),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.center_focus_strong,
            color: green,
            size: 28,
          ),
          SizedBox(height: 7),
          Text(
            'Scan a heritage attraction',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight:
              FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Take a photo or choose one from your gallery to recognise the landmark.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black45,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(9),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.image_search,
            color: Colors.orange,
            size: 27,
          ),

          const SizedBox(height: 6),

          Text(
            _message ?? '',
            textAlign:
            TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 7.5,
              height: 1.4,
            ),
          ),

          if (_candidates.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Vision candidates: '
                  '${_candidates.take(3).join(', ')}',
              textAlign:
              TextAlign.center,
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _locationText(
      HeritageAttraction attraction,
      ) {
    final city =
    attraction.city.trim();

    final state =
    attraction.state.trim();

    if (city.isEmpty) {
      return '$state, Malaysia';
    }

    if (city.toLowerCase() ==
        state.toLowerCase()) {
      return '$state, Malaysia';
    }

    return '$city, $state, Malaysia';
  }

  String _formatHistoryDate(
      DateTime value,
      ) {
    final date = value.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}
