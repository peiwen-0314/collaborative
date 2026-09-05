import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AttractionMapSelection {
  const AttractionMapSelection({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;
}

class AttractionMapPickerPage extends StatefulWidget {
  const AttractionMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialSearchText = '',
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String initialSearchText;

  @override
  State<AttractionMapPickerPage> createState() =>
      _AttractionMapPickerPageState();
}

class _AttractionMapPickerPageState
    extends State<AttractionMapPickerPage> {
  static const Color mainGreen = Color(0xFF0B6B2B);

  final MapController _mapController = MapController();
  late final TextEditingController _searchController;

  LatLng? _selectedPoint;
  String? _selectedAddress;
  bool _searching = false;
  List<_PlaceSearchResult> _results = [];

  bool get _hasValidInitialPoint {
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;

    return lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  LatLng get _initialCenter {
    if (_hasValidInitialPoint) {
      return LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }

    // Malaysia overview.
    return const LatLng(4.2105, 101.9758);
  }

  double get _initialZoom =>
      _hasValidInitialPoint ? 16 : 6.3;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: widget.initialSearchText,
    );

    if (_hasValidInitialPoint) {
      _selectedPoint = _initialCenter;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlace() async {
    final query = _searchController.text.trim();

    if (query.length < 3) {
      _showMessage(
        'Enter at least 3 characters to search.',
        error: true,
      );
      return;
    }

    setState(() {
      _searching = true;
      _results = [];
    });

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'q': query,
          'format': 'jsonv2',
          'limit': '5',
          'countrycodes': 'my',
          'addressdetails': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Map search returned ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception('Unexpected map search response.');
      }

      final results = decoded
          .whereType<Map<String, dynamic>>()
          .map(_PlaceSearchResult.fromJson)
          .where(
            (item) =>
                item.latitude != null &&
                item.longitude != null,
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
      });

      if (results.isEmpty) {
        _showMessage(
          'No matching place found in Malaysia.',
          error: true,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to search the map. You can still pan the map and tap the location manually.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  void _selectSearchResult(
    _PlaceSearchResult result,
  ) {
    final latitude = result.latitude;
    final longitude = result.longitude;

    if (latitude == null || longitude == null) {
      return;
    }

    final point = LatLng(
      latitude,
      longitude,
    );

    setState(() {
      _selectedPoint = point;
      _selectedAddress = result.displayName;
      _results = [];
      _searchController.text =
          result.displayName;
    });

    _mapController.move(
      point,
      17,
    );
  }

  void _selectMapPoint(
    TapPosition tapPosition,
    LatLng point,
  ) {
    setState(() {
      _selectedPoint = point;
      _selectedAddress = null;
      _results = [];
    });
  }

  void _confirmSelection() {
    final selected = _selectedPoint;

    if (selected == null) {
      _showMessage(
        'Search for a place or tap a point on the map first.',
        error: true,
      );
      return;
    }

    Navigator.pop(
      context,
      AttractionMapSelection(
        latitude: selected.latitude,
        longitude: selected.longitude,
        address: _selectedAddress,
      ),
    );
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? Colors.red : mainGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPoint;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title:
            const Text(
          'Find Attraction on Map',
        ),
        backgroundColor:
            Colors.white,
        foregroundColor:
            const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              12,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                          TextField(
                        controller:
                            _searchController,
                        textInputAction:
                            TextInputAction.search,
                        onSubmitted:
                            (_) =>
                                _searchPlace(),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Search attraction name or address...',
                          prefixIcon:
                              const Icon(
                            Icons.search,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    SizedBox(
                      height: 50,
                      child:
                          ElevatedButton.icon(
                        onPressed:
                            _searching
                                ? null
                                : _searchPlace,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              mainGreen,
                          foregroundColor:
                              Colors.white,
                        ),
                        icon:
                            _searching
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.3,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .travel_explore,
                                  ),
                        label:
                            Text(
                          _searching
                              ? 'Searching...'
                              : 'Search',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    constraints:
                        const BoxConstraints(
                      maxHeight: 230,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      border:
                          Border.all(
                        color:
                            const Color(
                          0xFFE5E7EB,
                        ),
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                    ),
                    child:
                        ListView.separated(
                      shrinkWrap: true,
                      itemCount:
                          _results.length,
                      separatorBuilder:
                          (_, __) =>
                              const Divider(
                        height: 1,
                      ),
                      itemBuilder:
                          (context, index) {
                        final result =
                            _results[index];

                        return ListTile(
                          leading:
                              const Icon(
                            Icons
                                .location_on_outlined,
                            color:
                                mainGreen,
                          ),
                          title:
                              Text(
                            result.displayName,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                          onTap: () =>
                              _selectSearchResult(
                            result,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController:
                      _mapController,
                  options:
                      MapOptions(
                    initialCenter:
                        _initialCenter,
                    initialZoom:
                        _initialZoom,
                    minZoom: 3,
                    maxZoom: 19,
                    onTap:
                        _selectMapPoint,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'my.edu.tarumt.collaborative_asg',
                    ),
                    if (selected !=
                        null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point:
                                selected,
                            width: 52,
                            height: 52,
                            alignment:
                                Alignment
                                    .topCenter,
                            child:
                                const Icon(
                              Icons
                                  .location_pin,
                              size: 50,
                              color:
                                  Colors.red,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                Positioned(
                  left: 12,
                  bottom: 12,
                  child:
                      Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(
                        0.92,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        5,
                      ),
                    ),
                    child:
                        const Text(
                      '© OpenStreetMap contributors',
                      style:
                          TextStyle(
                        fontSize: 10,
                        color:
                            Color(
                          0xFF475467,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child:
                      selected == null
                          ? const Text(
                              'Search for a place or tap anywhere on the map.',
                              style:
                                  TextStyle(
                                color:
                                    Color(
                                  0xFF667085,
                                ),
                              ),
                            )
                          : Text(
                              'Latitude: ${selected.latitude.toStringAsFixed(6)}    '
                              'Longitude: ${selected.longitude.toStringAsFixed(6)}',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                ),
                const SizedBox(
                  width: 16,
                ),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(
                    context,
                  ),
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                ElevatedButton.icon(
                  onPressed:
                      selected == null
                          ? null
                          : _confirmSelection,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        mainGreen,
                    foregroundColor:
                        Colors.white,
                  ),
                  icon:
                      const Icon(
                    Icons.check,
                  ),
                  label:
                      const Text(
                    'Use This Location',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSearchResult {
  const _PlaceSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double? latitude;
  final double? longitude;

  factory _PlaceSearchResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return _PlaceSearchResult(
      displayName:
          (json['display_name'] ?? '')
              .toString()
              .trim(),
      latitude:
          double.tryParse(
        (json['lat'] ?? '')
            .toString(),
      ),
      longitude:
          double.tryParse(
        (json['lon'] ?? '')
            .toString(),
      ),
    );
  }
}
