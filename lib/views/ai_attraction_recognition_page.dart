import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/heritage_attraction.dart';
import '../services/heritage_recognition_service.dart';
import '../services/heritage_storage_service.dart';
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

  final ImagePicker _picker = ImagePicker();
  final HeritageRecognitionService _recognition = HeritageRecognitionService();
  final HeritageStorageService _storage = HeritageStorageService();

  XFile? _image;
  HeritageAttraction? _attraction;
  List<String> _candidates = const [];
  bool _loading = false;
  String? _message;

  Future<void> _pick(ImageSource source) async {
    final selected = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (selected == null || !mounted) return;

    setState(() {
      _image = selected;
      _attraction = null;
      _candidates = const [];
      _message = null;
    });
    await _recognize();
  }

  Future<void> _recognize() async {
    if (_image == null) return;
    setState(() => _loading = true);

    try {
      final result = await _recognition.recognize(File(_image!.path));
      if (!mounted) return;

      setState(() {
        _candidates = result.candidates;
        _attraction = result.attraction;
        _message = result.attraction == null
            ? 'Google Vision returned a result, but it is not one of the supported heritage attractions.'
            : null;
      });

      if (result.attraction != null) {
        await _storage.addRecognition(result.attraction!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message =
            'Unable to reach the recognition backend. Start heritage_backend first.\n\n$error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!widget.embedded)
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Attraction Recognition',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan, discover, learn and travel sustainably.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Recognition History',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecognitionHistoryPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.history, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 290,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: paleGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_image != null)
                  Image.file(File(_image!.path), fit: BoxFit.cover)
                else
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance, color: green, size: 70),
                      SizedBox(height: 10),
                      Text(
                        'Capture or upload a heritage attraction',
                        style: TextStyle(
                          color: green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: _circleButton(
                    icon: Icons.photo_library_outlined,
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: InkWell(
                      onTap: () => _pick(ImageSource.camera),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: green, width: 4),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: green,
                          size: 29,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: green),
                    SizedBox(height: 10),
                    Text(
                      'Recognising attraction...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          else if (_attraction != null)
            _resultCard(_attraction!)
          else if (_message != null)
            _messageCard()
          else
            _instructionCard(),
        ],
      ),
    );

    if (widget.embedded) return ColoredBox(color: Colors.black, child: content);
    return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: content));
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _instructionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(Icons.center_focus_strong, color: green, size: 33),
          SizedBox(height: 9),
          Text(
            'Point your camera at a landmark',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Google Cloud Vision will return possible landmark names. EcoTravel then matches the result with the supported Cultural & Heritage dataset.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _messageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.image_search, color: Colors.orange, size: 34),
          const SizedBox(height: 8),
          Text(
            _message!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          if (_candidates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Vision candidates: ${_candidates.take(4).join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(HeritageAttraction attraction) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  attraction.imageAsset,
                  width: 88,
                  height: 105,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recognition Result',
                      style: TextStyle(
                        color: green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      attraction.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${attraction.state}, Malaysia',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            attraction.shortDescription,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HeritageDetailPage(attraction: attraction),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('View Heritage Details'),
            ),
          ),
        ],
      ),
    );
  }
}
