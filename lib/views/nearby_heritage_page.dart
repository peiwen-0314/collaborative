import 'package:flutter/material.dart';

import '../services/heritage_nearby_service.dart';
import '../widgets/heritage_image.dart';
import 'heritage_detail_page.dart';

class NearbyHeritagePage extends StatefulWidget {
  const NearbyHeritagePage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<NearbyHeritagePage> createState() => _NearbyHeritagePageState();
}

class _NearbyHeritagePageState extends State<NearbyHeritagePage> {
  static const Color green = Color(0xFF2E7D32);

  final HeritageNearbyService _nearbyService = HeritageNearbyService();
  bool _checking = false;
  String? _message;
  List<NearbyHeritageResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _nearbyService.initializeNotifications();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final results = await _nearbyService.findNearby(radiusMeters: 1000);
      if (!mounted) return;
      setState(() {
        _results = results;
        _message = results.isEmpty
            ? 'No supported heritage attraction was found within 1 km.'
            : null;
      });
      if (results.isNotEmpty) {
        await _nearbyService.showNearbyNotification(results.first);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _checking = false);
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
                      'Nearby Heritage',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Discover cultural places around your current location.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const CircleAvatar(
                backgroundColor: Color(0xFFDDF4D8),
                child: Icon(Icons.location_on_outlined, color: green),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.travel_explore, color: green, size: 48),
                const SizedBox(height: 9),
                const Text(
                  'Check attractions within 1 km',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'EcoTravel uses your current location only when you request a nearby check.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: green),
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.my_location),
                    label: Text(_checking ? 'Checking...' : 'Check Nearby Heritage'),
                  ),
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_message!, style: const TextStyle(fontSize: 12)),
            ),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Nearby Results',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ..._results.map((result) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(9),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HeritageImage(
                      imageUrl: result.attraction.imageUrl,
                      width: 58,
                      height: 68,
                    ),
                  ),
                  title: Text(
                    result.attraction.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${result.distanceMeters.round()} m away\n${result.attraction.state}, Malaysia',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HeritageDetailPage(
                          attraction: result.attraction,
                        ),
                      ),
                    );
                  },
                ),
              ),
            )),
          ],
        ],
      ),
    );

    if (widget.embedded) return ColoredBox(color: Colors.black, child: content);
    return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: content));
  }
}
