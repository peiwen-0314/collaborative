import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:collaborative_asg/firebase_options.dart';
import 'package:collaborative_asg/services/heritage_content_seed_service.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HeritageSeedApp());
}

class HeritageSeedApp extends StatelessWidget {
  const HeritageSeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E8B3C),
        ),
      ),
      home: const HeritageSeedPage(),
    );
  }
}

class HeritageSeedPage extends StatefulWidget {
  const HeritageSeedPage({super.key});

  @override
  State<HeritageSeedPage> createState() => _HeritageSeedPageState();
}

class _HeritageSeedPageState extends State<HeritageSeedPage> {
  final HeritageContentSeedService _seedService = HeritageContentSeedService();
  bool _loading = false;
  String _message =
      'Uploads H001-H005 text/location/audio fields only. No image is uploaded.';

  Future<void> _upload() async {
    setState(() {
      _loading = true;
      _message = 'Uploading...';
    });

    try {
      final count = await _seedService.uploadStarterContent();
      if (!mounted) return;
      setState(() {
        _message = '$count heritage records uploaded successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Upload failed: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heritage Firestore Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One-time content upload',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This writes only to the heritage_attractions collection in the same Firebase project. It does not touch users and it does not upload images.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _upload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _loading ? 'Uploading...' : 'Upload Heritage Content',
                ),
              ),
            ),
            const SizedBox(height: 20),
            SelectableText(_message),
          ],
        ),
      ),
    );
  }
}
