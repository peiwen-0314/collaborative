import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/heritage_attraction.dart';
import '../widgets/heritage_image.dart';

class HeritageDetailPage extends StatefulWidget {
  const HeritageDetailPage({
    super.key,
    required this.attraction,
  });

  final HeritageAttraction attraction;

  @override
  State<HeritageDetailPage> createState() =>
      _HeritageDetailPageState();
}

class _HeritageDetailPageState extends State<HeritageDetailPage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color paleGreen = Color(0xFFEAF6E8);
  static const Color borderColor = Color(0xFFE2E7E0);
  static const Color pageBackground = Color(0xFFFAFBF9);

  final FlutterTts _tts = FlutterTts();

  String _language = 'English';
  bool _speaking = false;
  bool _showFullHistory = false;
  bool _showConservation = true;
  bool _showEtiquette = true;
  bool _showOthers = true;

  HeritageAttraction get attraction => widget.attraction;

  String get _guideText {
    if (_language == 'Bahasa Melayu') {
      return attraction.audioMalay;
    }

    if (_language == '中文') {
      return attraction.audioChinese;
    }

    return attraction.audioEnglish;
  }

  String get _ttsLanguage {
    if (_language == 'Bahasa Melayu') {
      return 'ms-MY';
    }

    if (_language == '中文') {
      return 'zh-CN';
    }

    return 'en-US';
  }

  @override
  void initState() {
    super.initState();

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    });

    _tts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    });

    _tts.setErrorHandler((_) {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_speaking) {
      await _tts.stop();

      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }

      return;
    }

    if (_guideText.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio guide content is not available yet.'),
        ),
      );

      return;
    }

    await _tts.setLanguage(_ttsLanguage);
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);

    if (mounted) {
      setState(() {
        _speaking = true;
      });
    }

    await _tts.speak(_guideText);
  }

  Future<void> _restartAudio() async {
    await _tts.stop();

    if (_guideText.trim().isEmpty) {
      return;
    }

    await _tts.setLanguage(_ttsLanguage);
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);

    if (mounted) {
      setState(() {
        _speaking = true;
      });
    }

    await _tts.speak(_guideText);
  }

  Future<void> _stopAudio() async {
    await _tts.stop();

    if (mounted) {
      setState(() {
        _speaking = false;
      });
    }
  }

  List<String> _itemsOrFallback(
      List<String> items,
      String fallback,
      ) {
    if (items.isNotEmpty) {
      return items;
    }

    final cleanFallback = fallback.trim();

    if (cleanFallback.isEmpty) {
      return const <String>[];
    }

    return <String>[cleanFallback];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 12),

              _buildHeroImage(),

              const SizedBox(height: 10),

              _buildBasicInformationCard(),

              const SizedBox(height: 15),

              _buildHistoricalBackground(),

              const SizedBox(height: 12),

              _buildExpandableSection(
                title: 'Conservation Guidelines',
                icon: Icons.eco_outlined,
                expanded: _showConservation,
                onTap: () {
                  setState(() {
                    _showConservation = !_showConservation;
                  });
                },
                child: _buildTwoColumnChecklist(
                  _itemsOrFallback(
                    attraction.conservationGuidelines,
                    '',
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _buildExpandableSection(
                title: 'Visitor Etiquette',
                icon: Icons.people_alt_outlined,
                expanded: _showEtiquette,
                onTap: () {
                  setState(() {
                    _showEtiquette = !_showEtiquette;
                  });
                },
                child: _buildTwoColumnChecklist(
                  _itemsOrFallback(
                    attraction.visitorEtiquetteItems,
                    attraction.visitorEtiquette,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _buildExpandableSection(
                title: 'Others',
                icon: Icons.more_horiz_rounded,
                expanded: _showOthers,
                onTap: () {
                  setState(() {
                    _showOthers = !_showOthers;
                  });
                },
                child: _buildOtherInformation(),
              ),

              const SizedBox(height: 12),

              _buildAudioGuide(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.maybePop(context),
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 25,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(width: 5),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historical Information',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Learn the stories behind every place.',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HERO IMAGE
  // ============================================================

  Widget _buildHeroImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: HeritageImage(
        imageUrl: attraction.imageUrl,
        width: double.infinity,
        height: 180,
      ),
    );
  }

  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  Widget _buildBasicInformationCard() {
    final heritageStatus = attraction.heritageStatus.trim().isNotEmpty
        ? attraction.heritageStatus
        : attraction.category;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attraction.name,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 10,
                color: Colors.black45,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  attraction.locationText,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 8.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            attraction.shortDescription,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 9.5,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 11),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildQuickInfo(
                  icon: Icons.calendar_today_outlined,
                  title: 'Year Built',
                  value: attraction.yearBuilt.trim().isEmpty
                      ? '—'
                      : attraction.yearBuilt,
                ),
              ),

              const SizedBox(width: 4),

              Expanded(
                child: _buildQuickInfo(
                  icon: Icons.account_balance_outlined,
                  title: 'Architectural Style',
                  value: attraction.architecturalStyle.trim().isEmpty
                      ? '—'
                      : attraction.architecturalStyle,
                ),
              ),

              const SizedBox(width: 4),

              Expanded(
                child: _buildQuickInfo(
                  icon: Icons.verified_outlined,
                  title: 'Heritage Status',
                  value: heritageStatus,
                ),
              ),

              const SizedBox(width: 4),

              Expanded(
                child: _buildQuickInfo(
                  icon: Icons.schedule_outlined,
                  title: 'Estimated Visit',
                  value: attraction.recommendedTime.trim().isEmpty
                      ? '—'
                      : attraction.recommendedTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 66,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFDDE4DA),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: green,
            size: 13,
          ),

          const SizedBox(height: 3),

          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: green,
              fontSize: 7.2,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 7.0,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORICAL BACKGROUND
  // ============================================================

  int _findHistorySplitIndex({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
  }) {
    if (text.isEmpty || maxWidth <= 0) return 0;

    int low = 0;
    int high = text.length;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;

      final painter = TextPainter(
        text: TextSpan(
          text: text.substring(0, mid),
          style: style,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    if (low <= 0 || low >= text.length) {
      return low;
    }

    // Avoid cutting a word in half.
    final nextSpace = text.indexOf(' ', low);

    if (nextSpace != -1 && nextSpace - low <= 12) {
      return nextSpace;
    }

    return low;
  }

  Widget _buildHistoricalBackground() {
    final history = attraction.history.trim();

    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: green,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'Historical Background',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: const Text(
              'Historical background has not been added yet.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 9,
                height: 1.45,
              ),
            ),
          ),
        ],
      );
    }

    final canCollapse = history.length > 330;

    final visibleHistory =
    canCollapse && !_showFullHistory && history.length > 430
        ? '${history.substring(0, 430).trim()}...'
        : history;

    const historyStyle = TextStyle(
      color: Colors.black54,
      fontSize: 9,
      height: 1.45,
    );

    const imageWidth = 82.0;
    const imageHeight = 84.0;
    const imageGap = 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: green,
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              'Historical Background',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textWidth =
                  constraints.maxWidth - imageWidth - imageGap;

              // Give the first text block a little extra height so it
              // fills the area beside the image instead of ending early
              // and leaving a blank gap underneath.
              final splitIndex = _findHistorySplitIndex(
                text: visibleHistory,
                maxWidth: textWidth,
                maxHeight: imageHeight + 18,
                style: historyStyle,
              );

              final topText =
              visibleHistory.substring(0, splitIndex).trim();

              final bottomText =
              visibleHistory.substring(splitIndex).trim();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          topText,
                          style: historyStyle,
                        ),
                      ),

                      const SizedBox(width: imageGap),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: HeritageImage(
                          imageUrl: attraction.imageUrl,
                          width: imageWidth,
                          height: imageHeight,
                        ),
                      ),
                    ],
                  ),

                  // As soon as the text reaches the bottom of the image,
                  // it continues immediately using the full card width.
                  if (bottomText.isNotEmpty) ...[
                    Text(
                      bottomText,
                      style: historyStyle,
                    ),
                  ],

                  if (canCollapse) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showFullHistory = !_showFullHistory;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showFullHistory
                                ? 'Show Less'
                                : 'Read More',
                            style: const TextStyle(
                              color: green,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            _showFullHistory
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: green,
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EXPANDABLE SECTION
  // ============================================================

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: green,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black54,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),

          if (expanded) ...[
            const Divider(
              height: 1,
              color: Color(0xFFEAEAEA),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CHECKLIST
  // ============================================================

  Widget _buildTwoColumnChecklist(List<String> items) {
    if (items.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Information not added yet.',
          style: TextStyle(
            color: Colors.black45,
            fontSize: 7,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 68) / 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: green,
                  size: 10,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 8.2,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // OTHERS
  // ============================================================

  Widget _buildOtherInformation() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSmallInformationCard(
            icon: Icons.checkroom_outlined,
            title: 'Dress Code',
            items: attraction.dressCode,
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: _buildSmallInformationCard(
            icon: Icons.photo_camera_outlined,
            title: 'Photography Restrictions',
            items: attraction.photographyRestrictions,
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: _buildSmallInformationCard(
            icon: Icons.health_and_safety_outlined,
            title: 'Preservation Practices',
            items: attraction.preservationPractices,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallInformationCard({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 98,
      ),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFC),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFFE5E9E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: green,
            size: 13,
          ),

          const SizedBox(height: 4),

          Text(
            title,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 7.8,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          if (items.isEmpty)
            const Text(
              'Not added yet',
              style: TextStyle(
                color: Colors.black38,
                fontSize: 7.2,
              ),
            )
          else
            ...items.take(3).map(
                  (item) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.circle,
                        size: 3,
                        color: green,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        item,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 7.0,
                          height: 1.2,
                        ),
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

  // ============================================================
  // AUDIO GUIDE
  // ============================================================

  Widget _buildAudioGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: paleGreen,
                child: Icon(
                  Icons.headphones_rounded,
                  color: green,
                  size: 13,
                ),
              ),
              SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Guide',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Listen to the historical story.',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 7.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              _languageButton('English'),
              const SizedBox(width: 5),
              _languageButton('Bahasa Melayu'),
              const SizedBox(width: 5),
              _languageButton('中文'),
            ],
          ),

          const SizedBox(height: 9),

          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFA),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: const Color(0xFFE8EAE7),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: HeritageImage(
                        imageUrl: attraction.imageUrl,
                        width: 42,
                        height: 42,
                      ),
                    ),

                    const SizedBox(width: 7),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attraction.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Historical Overview',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 7.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      _speaking ? 'Playing' : 'Ready',
                      style: TextStyle(
                        color: _speaking ? green : Colors.black38,
                        fontSize: 7.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    value: _speaking ? null : 0,
                    backgroundColor: const Color(0xFFE7E7E7),
                    color: green,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _restartAudio,
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: Colors.black54,
                        size: 18,
                      ),
                    ),

                    const SizedBox(width: 12),

                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggleAudio,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _speaking
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _stopAudio,
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: Colors.black54,
                        size: 18,
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

  Widget _languageButton(String language) {
    final selected = _language == language;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await _tts.stop();

          if (!mounted) return;

          setState(() {
            _language = language;
            _speaking = false;
          });
        },
        child: Container(
          height: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? green : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? green
                  : const Color(0xFFD9DDD8),
            ),
          ),
          child: Text(
            language,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black54,
              fontSize: 7.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
