import 'package:flutter/material.dart';

import '../services/heritage_storage_service.dart';
import '../widgets/heritage_image.dart';
import 'heritage_detail_page.dart';

class RecognitionHistoryPage extends StatefulWidget {
  const RecognitionHistoryPage({super.key});

  @override
  State<RecognitionHistoryPage> createState() => _RecognitionHistoryPageState();
}

class _RecognitionHistoryPageState extends State<RecognitionHistoryPage> {
  final HeritageStorageService _storage = HeritageStorageService();
  bool _loading = true;
  List<RecognitionHistoryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.loadRecognitionHistory();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Recognition History'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      )
          : _entries.isEmpty
          ? const Center(
        child: Text(
          'No recognition history yet.',
          style: TextStyle(color: Colors.white70),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final date = entry.recognizedAt.toLocal();
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: HeritageImage(
                  imageUrl: entry.attraction.imageUrl,
                  width: 52,
                  height: 62,
                ),
              ),
              title: Text(
                entry.attraction.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${date.day}/${date.month}/${date.year} '
                    '${date.hour.toString().padLeft(2, '0')}:'
                    '${date.minute.toString().padLeft(2, '0')}',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HeritageDetailPage(
                      attraction: entry.attraction,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
