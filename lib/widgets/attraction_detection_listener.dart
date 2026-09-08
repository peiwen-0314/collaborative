import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/attraction_detection_result.dart';
import '../services/attraction_detection_service.dart';
import '../views/digital_passport_page.dart';

class AttractionDetectionListener extends StatefulWidget {
  const AttractionDetectionListener({
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AttractionDetectionListener> createState() =>
      _AttractionDetectionListenerState();
}

class _AttractionDetectionListenerState
    extends State<AttractionDetectionListener> {
  final AttractionDetectionService _service = AttractionDetectionService();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<AttractionDetectionResult>? _subscription;
  bool _popupOpen = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _subscription?.cancel();
      _subscription = null;
      if (user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _startDetection());
      }
    });
  }

  Future<void> _startDetection() async {
    try {
      await _subscription?.cancel();
      final stream = await _service.start();
      _subscription = stream.listen(_showArrivalPopup);
    } catch (error) {
      if (!mounted) return;
      final navigatorContext = widget.navigatorKey.currentContext;
      if (navigatorContext == null) return;
      ScaffoldMessenger.of(navigatorContext).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _showArrivalPopup(AttractionDetectionResult result) async {
    if (!mounted || _popupOpen) return;
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _popupOpen = true;

    await showModalBottomSheet<void>(
      context: navigatorContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ArrivalRewardCard(result: result),
    );

    _popupOpen = false;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ArrivalRewardCard extends StatelessWidget {
  const _ArrivalRewardCard({required this.result});

  final AttractionDetectionResult result;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: BoxDecoration(
          color: const Color(0xFFF4FAF1),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCAD6C6),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            const Icon(Icons.location_on, color: AppColors.green, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Attraction Detected!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              'You have arrived at ${result.attraction.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 15),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.green, size: 21),
                SizedBox(width: 7),
                Text(
                  'Stamp automatically collected',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _RewardBox(
                    icon: Icons.stars,
                    value: '+${result.pointsAwarded}',
                    label: 'Points',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RewardBox(
                    icon: Icons.bolt,
                    value: '+${result.xpAwarded}',
                    label: 'XP',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DigitalPassportPage(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                    child: const Text('View Stamp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardBox extends StatelessWidget {
  const _RewardBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E8D3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.green),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
