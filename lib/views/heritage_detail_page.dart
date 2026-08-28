import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/heritage_attraction.dart';
import '../services/heritage_storage_service.dart';
import 'heritage_diary_page.dart';

class HeritageDetailPage extends StatefulWidget {
  const HeritageDetailPage({
    super.key,
    required this.attraction,
  });

  final HeritageAttraction attraction;

  @override
  State<HeritageDetailPage> createState() => _HeritageDetailPageState();
}

class _HeritageDetailPageState extends State<HeritageDetailPage> {
  static const Color green = Color(0xFF2E7D32);
  static const Color paleGreen = Color(0xFFE7F5E5);

  final FlutterTts _tts = FlutterTts();
  final HeritageStorageService _storage = HeritageStorageService();

  String _language = 'English';
  bool _speaking = false;

  String get _guideText {
    if (_language == 'Bahasa Melayu') return widget.attraction.audioMalay;
    if (_language == '中文') return widget.attraction.audioChinese;
    return widget.attraction.audioEnglish;
  }

  String get _ttsLanguage {
    if (_language == 'Bahasa Melayu') return 'ms-MY';
    if (_language == '中文') return 'zh-CN';
    return 'en-US';
  }

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
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
      if (mounted) setState(() => _speaking = false);
      return;
    }
    await _tts.setLanguage(_ttsLanguage);
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    if (mounted) setState(() => _speaking = true);
    await _tts.speak(_guideText);
  }

  Future<void> _addToDiary() async {
    await _storage.addToDiary(widget.attraction);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: green,
        content: Text('Added to your Cultural & Heritage travel diary.'),
      ),
    );
  }

  Future<void> _openMap() async {
    final attraction = widget.attraction;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${attraction.latitude},${attraction.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final attraction = widget.attraction;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Heritage Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Travel Diary',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HeritageDiaryPage(),
                ),
              );
            },
            icon: const Icon(Icons.auto_stories_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                attraction.imageAsset,
                width: double.infinity,
                height: 245,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              attraction.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 17, color: green),
                const SizedBox(width: 4),
                Text(
                  '${attraction.city}, ${attraction.state}, Malaysia',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _chip(attraction.category),
                _chip('Open ${attraction.openingHours}'),
                _chip(attraction.recommendedTime),
              ],
            ),
            const SizedBox(height: 19),
            Text(
              attraction.shortDescription,
              style: const TextStyle(fontSize: 14, height: 1.55),
            ),
            const SizedBox(height: 18),
            _infoCard(
              icon: Icons.history_edu_outlined,
              title: 'Historical Background',
              body: attraction.history,
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.diversity_3_outlined,
              title: 'Cultural Significance',
              body: attraction.culturalSignificance,
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'Visitor Etiquette',
              body: attraction.visitorEtiquette,
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.eco_outlined,
              title: 'Sustainable Travel Tip',
              body: attraction.sustainabilityTip,
              greenBackground: true,
            ),
            const SizedBox(height: 20),
            const Text(
              'Multilingual Audio Guide',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: paleGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.translate, color: green),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English')),
                      DropdownMenuItem(
                        value: 'Bahasa Melayu',
                        child: Text('Bahasa Melayu'),
                      ),
                      DropdownMenuItem(value: '中文', child: Text('中文')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _tts.stop();
                        setState(() {
                          _language = value;
                          _speaking = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _guideText,
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: green),
                      onPressed: _toggleAudio,
                      icon: Icon(
                        _speaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                      ),
                      label: Text(
                        _speaking ? 'Stop Audio Guide' : 'Play Audio Guide',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openMap,
                    style: OutlinedButton.styleFrom(foregroundColor: green),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View On Map'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addToDiary,
                    style: FilledButton.styleFrom(backgroundColor: green),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Add To Diary'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: green,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
    bool greenBackground = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: greenBackground ? paleGreen : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE1E5DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: green, size: 21),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            body,
            style: const TextStyle(fontSize: 12.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}
