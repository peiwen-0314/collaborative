import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_theme.dart';
import '../models/gamification_summary.dart';
import '../models/heritage_attraction.dart';
import '../models/passport_stamp.dart';
import '../services/gamification_service.dart';
import '../services/heritage_firestore_service.dart';
import '../services/passport_service.dart';
import 'all_stamps_page.dart';

class DigitalPassportPage extends StatefulWidget {
  const DigitalPassportPage({super.key});

  @override
  State<DigitalPassportPage> createState() => _DigitalPassportPageState();
}

class _DigitalPassportPageState extends State<DigitalPassportPage> {
  final GamificationService _gamificationService = GamificationService();
  final PassportService _passportService = PassportService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: const Text(
          'Digital Passport',
          style: TextStyle(
            color: Color(0xFF202020),
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<GamificationSummary>(
        stream: _gamificationService.watchCurrentUserSummary(),
        builder: (context, summarySnapshot) {
          if (summarySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (summarySnapshot.hasError || summarySnapshot.data == null) {
            return _ErrorState(
              message: summarySnapshot.error?.toString() ??
                  'Passport progress is unavailable.',
            );
          }

          final summary = summarySnapshot.data!;
          return StreamBuilder<List<PassportStamp>>(
            stream: _passportService.watchAllStamps(),
            builder: (context, stampSnapshot) {
              if (stampSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (stampSnapshot.hasError) {
                return _ErrorState(message: stampSnapshot.error.toString());
              }

              final stamps = stampSnapshot.data ?? const <PassportStamp>[];
              final recentStamps = stamps.take(3).toList();
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                child: Column(
                  children: [
                    _PassportProgressCard(summary: summary),
                    const SizedBox(height: 22),
                    _RecentStampCard(stamps: recentStamps),
                    const SizedBox(height: 22),
                    _MalaysiaMapCard(stamps: stamps),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PassportProgressCard extends StatelessWidget {
  const _PassportProgressCard({required this.summary});

  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    final double progress =
    summary.totalStamps <= 0
        ? 0.0
        : (summary.collectedStamps /
        summary.totalStamps)
        .clamp(0.0, 1.0)
        .toDouble();

    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/digitalPassport.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 170,
                  color: const Color(0xFFF4F2E8),
                  child: const Center(
                    child: Icon(
                      Icons.badge,
                      size: 70,
                      color: AppColors.green,
                    ),
                  ),
                );
              },
            ),

            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.49,
                  heightFactor: 0.82,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 10,
                      right: 14,
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 165,
                        height: 92,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Passport Progress',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1,
                                fontWeight:
                                FontWeight.w700,
                                color: Color(0xFF202020),
                              ),
                            ),

                            const Spacer(),

                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${summary.collectedStamps}',
                                  style: const TextStyle(
                                    fontSize: 39,
                                    height: 0.88,
                                    fontWeight:
                                    FontWeight.w800,
                                    color: Color(0xFF111111),
                                  ),
                                ),

                                const SizedBox(width: 4),

                                Padding(
                                  padding:
                                  const EdgeInsets.only(
                                    bottom: 3,
                                  ),
                                  child: Text(
                                    '/ ${summary.totalStamps}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1,
                                      fontWeight:
                                      FontWeight.w700,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            SizedBox(
                              width: 125,
                              child: ClipRRect(
                                borderRadius:
                                BorderRadius.circular(20),
                                child:
                                LinearProgressIndicator(
                                  minHeight: 7,
                                  value: progress,
                                  backgroundColor:
                                  const Color(0xFFE0E0DC),
                                  valueColor:
                                  const AlwaysStoppedAnimation<
                                      Color>(
                                    Color(0xFF73944D),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentStampCard extends StatelessWidget {
  const _RecentStampCard({required this.stamps});

  final List<PassportStamp> stamps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Recent Stamp',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF535353)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AllStampsPage()),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(color: AppColors.green, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (stamps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('No stamps collected yet.'),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(stamps.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 5,
                      right: index == stamps.length - 1 ? 0 : 5,
                    ),
                    child: _StampTile(stamp: stamps[index]),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _StampTile extends StatelessWidget {
  const _StampTile({required this.stamp});

  final PassportStamp stamp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(42)),
            child: _buildStampImage(),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 34,
          child: Text(
            stamp.attractionName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _formatDate(stamp.collectedAt),
          maxLines: 1,
          style: const TextStyle(fontSize: 9, color: Color(0xFFB8B8B8)),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildStampImage() {
    Widget placeholder() => Container(
      color: const Color(0xFFEAF4E7),
      child: const Icon(
        Icons.account_balance,
        color: AppColors.green,
        size: 38,
      ),
    );

    Widget localFallback() {
      if (stamp.imageName.isEmpty) return placeholder();
      return Image.asset(
        'assets/images/${stamp.imageName}',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    if (stamp.stampImageUrl.isEmpty) return localFallback();
    return Image.network(
      stamp.stampImageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
        color: const Color(0xFFEAF4E7),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorBuilder: (_, __, ___) => localFallback(),
    );
  }
}

class _MalaysiaMapCard extends StatefulWidget {
  const _MalaysiaMapCard({required this.stamps});

  final List<PassportStamp> stamps;

  @override
  State<_MalaysiaMapCard> createState() => _MalaysiaMapCardState();
}

class _MalaysiaMapCardState extends State<_MalaysiaMapCard> {
  List<Polygon> _malaysiaPolygons = const [];
  final HeritageFirestoreService _heritageService = HeritageFirestoreService();

  @override
  void initState() {
    super.initState();
    _loadMalaysiaBoundary();
  }

  Future<void> _loadMalaysiaBoundary() async {
    final jsonText = await rootBundle.loadString('assets/maps/malaysia.min.geojson');
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final polygons = <Polygon>[];

    void addRing(List<dynamic> ring) {
      polygons.add(
        Polygon(
          points: ring.map((coordinate) {
            final pair = coordinate as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          }).toList(),
          color: const Color(0x553F7F3A),
          borderColor: const Color(0xFF3F7F3A),
          borderStrokeWidth: 1.5,
        ),
      );
    }

    void readGeometry(Map<String, dynamic> geometry) {
      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates == null) return;

      if (type == 'Polygon' && coordinates.isNotEmpty) {
        addRing(coordinates.first as List<dynamic>);
      } else if (type == 'MultiPolygon') {
        for (final polygon in coordinates) {
          final rings = polygon as List<dynamic>;
          if (rings.isNotEmpty) addRing(rings.first as List<dynamic>);
        }
      }
    }

    if (decoded['type'] == 'FeatureCollection') {
      for (final feature in decoded['features'] as List<dynamic>) {
        final geometry = (feature as Map<String, dynamic>)['geometry'];
        if (geometry is Map<String, dynamic>) readGeometry(geometry);
      }
    } else if (decoded['type'] == 'Feature') {
      final geometry = decoded['geometry'];
      if (geometry is Map<String, dynamic>) readGeometry(geometry);
    } else {
      readGeometry(decoded);
    }

    if (mounted) setState(() => _malaysiaPolygons = polygons);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HeritageAttraction>>(
      stream: _heritageService.watchAttractions(),
      builder: (context, snapshot) {
        final attractions = snapshot.data ?? const <HeritageAttraction>[];
        return _buildMapCard(attractions);
      },
    );
  }

  Widget _buildMapCard(List<HeritageAttraction> attractions) {
    final visitedIds = widget.stamps
        .map((stamp) => stamp.attractionId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final mappedAttractions = attractions
        .where((attraction) =>
    attraction.latitude != 0 && attraction.longitude != 0)
        .toList()
      ..sort((a, b) {
        final aVisited = visitedIds.contains(a.id) ? 1 : 0;
        final bVisited = visitedIds.contains(b.id) ? 1 : 0;
        return aVisited.compareTo(bVisited);
      });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Malaysia Map',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF535353)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 2.05,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(4.2, 109.5),
                  initialZoom: 4.25,
                  minZoom: 4,
                  maxZoom: 18,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-1.5, 98.0),
                      const LatLng(9.0, 121.0),
                    ),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.example.collaborative_asg',
                  ),
                  if (_malaysiaPolygons.isNotEmpty)
                    PolygonLayer(polygons: _malaysiaPolygons),
                  MarkerLayer(
                    markers: mappedAttractions.map((attraction) {
                      final isComingSoon = attraction.mapStatus
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z]'), '') ==
                          'comingsoon';
                      final isVisited = visitedIds.contains(attraction.id);
                      final color = isComingSoon
                          ? const Color(0xFFE86E3C)
                          : isVisited
                          ? const Color(0xFF315E2C)
                          : const Color(0xFF9C9C9C);
                      return Marker(
                        point: LatLng(
                          attraction.latitude,
                          attraction.longitude,
                        ),
                        width: 28,
                        height: 32,
                        alignment: Alignment.bottomCenter,
                        child: Tooltip(
                          message: attraction.name,
                          child: _MapPin(color: color),
                        ),
                      );
                    }).toList(),
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap · © CARTO'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.green, label: 'Visited'),
              SizedBox(width: 18),
              _LegendDot(color: Color(0xFF9C9C9C), label: 'Not Visited'),
              SizedBox(width: 18),
              _LegendDot(color: Color(0xFFE86E3C), label: 'Coming Soon'),
            ],
          ),
        ],
      ),
    );
  }

}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_on,
      color: color,
      size: 28,
      shadows: const [
        Shadow(
          color: Color(0x55000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 8)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message.replaceFirst('Bad state: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x17000000), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );
}

