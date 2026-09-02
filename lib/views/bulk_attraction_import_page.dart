import 'package:flutter/material.dart';

import '../controllers/attraction_import_controller.dart';
import '../services/geoapify_attraction_service.dart';

class BulkAttractionImportPage extends StatefulWidget {
  const BulkAttractionImportPage({super.key});

  @override
  State<BulkAttractionImportPage> createState() =>
      _BulkAttractionImportPageState();
}

class _BulkAttractionImportPageState
    extends State<BulkAttractionImportPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color secondaryText = Color(0xFF777777);

  final AttractionImportController _controller =
      AttractionImportController();

  final TextEditingController _areaController =
      TextEditingController(text: 'Kuala Lumpur');

  String? _selectedState = 'Kuala Lumpur';
  int _radiusKm = 20;

  static const List<String> malaysiaStates = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Penang',
    'Perak',
    'Perlis',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'Kuala Lumpur',
    'Labuan',
    'Putrajaya',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Import Attractions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _introCard(),
                    const SizedBox(height: 16),
                    _searchCard(),

                    if (_controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _messageBox(
                        _controller.errorMessage!,
                        isError: true,
                      ),
                    ],

                    if (_controller.successMessage != null) ...[
                      const SizedBox(height: 12),
                      _messageBox(_controller.successMessage!),
                    ],

                    const SizedBox(height: 18),

                    if (_controller.results.isNotEmpty)
                      _resultHeader(),

                    const SizedBox(height: 10),

                    ..._controller.results.map(_attractionTile),

                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),

            if (_controller.results.isNotEmpty)
              _bottomImportBar(),
          ],
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Malaysia Attraction Bulk Import',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: mainGreen,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Search a Malaysian city or area, preview attractions '
            'from Geoapify, select useful places, then import them '
            'into Firestore.',
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E8E5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Area',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration: _inputDecoration(
              'State / Federal Territory',
            ),
            items: malaysiaStates
                .map(
                  (state) => DropdownMenuItem(
                    value: state,
                    child: Text(state),
                  ),
                )
                .toList(),
            onChanged: _controller.isSearching
                ? null
                : (value) {
                    setState(() {
                      _selectedState = value;
                    });
                  },
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _areaController,
            enabled: !_controller.isSearching,
            decoration: _inputDecoration(
              'Area / City',
            ).copyWith(
              hintText:
                  'e.g. George Town, Langkawi, Melaka City',
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Text(
                'Search radius',
                style: TextStyle(
                  fontSize: 10,
                  color: secondaryText,
                ),
              ),
              const Spacer(),
              Text(
                '$_radiusKm km',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: mainGreen,
                ),
              ),
            ],
          ),

          Slider(
            value: _radiusKm.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            activeColor: mainGreen,
            onChanged: _controller.isSearching
                ? null
                : (value) {
                    setState(() {
                      _radiusKm = value.round();
                    });
                  },
          ),

          SizedBox(
            width: double.infinity,
            height: 43,
            child: ElevatedButton.icon(
              onPressed: _controller.isSearching
                  ? null
                  : () {
                      _controller.search(
                        area: _areaController.text,
                        state: _selectedState,
                        radiusKm: _radiusKm,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: mainGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _controller.isSearching
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.travel_explore_rounded,
                      size: 18,
                    ),
              label: Text(
                _controller.isSearching
                    ? 'Searching...'
                    : 'Find Attractions',
              ),
            ),
          ),

          if (!_controller.hasApiKey) ...[
            const SizedBox(height: 10),
            const Text(
              'API key not detected. Run with '
              '--dart-define=GEOAPIFY_API_KEY=YOUR_KEY',
              style: TextStyle(
                fontSize: 8.5,
                color: Colors.redAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_controller.results.length} Attractions',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: _controller.selectedCount ==
                  _controller.results.length
              ? _controller.clearSelection
              : _controller.selectAll,
          child: Text(
            _controller.selectedCount ==
                    _controller.results.length
                ? 'Clear All'
                : 'Select All',
            style: const TextStyle(
              color: mainGreen,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _attractionTile(GeoapifyAttractionCandidate item) {
    final selected = _controller.isSelected(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? mainGreen
              : const Color(0xFFE5E5E5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            activeColor: mainGreen,
            onChanged: _controller.isImporting
                ? null
                : (_) => _controller.toggleSelected(item),
          ),
          const SizedBox(width: 2),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _location(item),
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: secondaryText,
                  ),
                ),

                if (item.address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 7.5,
                      color: secondaryText,
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.categoryName,
                    style: const TextStyle(
                      fontSize: 7.5,
                      color: mainGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomImportBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE7E7E7),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _controller.importStatus,
              decoration: _inputDecoration('Import Status'),
              items: const [
                DropdownMenuItem(
                  value: 'Draft',
                  child: Text('Draft'),
                ),
                DropdownMenuItem(
                  value: 'Active',
                  child: Text('Active'),
                ),
              ],
              onChanged: _controller.isImporting
                  ? null
                  : (value) {
                      if (value != null) {
                        _controller.setImportStatus(value);
                      }
                    },
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: SizedBox(
              height: 45,
              child: ElevatedButton(
                onPressed: _controller.isImporting ||
                        _controller.selectedCount == 0
                    ? null
                    : () async {
                        final summary =
                            await _controller.importSelected();

                        if (!mounted) return;

                        if (summary.imported > 0) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                '${summary.imported} attraction(s) imported.',
                              ),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _controller.isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Import (${_controller.selectedCount})',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFDDDDDD),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: mainGreen,
        ),
      ),
    );
  }

  Widget _messageBox(
    String text, {
    bool isError = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFFEEEE)
            : lightGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: isError
              ? Colors.red.shade700
              : mainGreen,
        ),
      ),
    );
  }

  String _location(GeoapifyAttractionCandidate item) {
    if (item.area.isEmpty) return item.state;
    if (item.state.isEmpty) return item.area;
    return '${item.area}, ${item.state}';
  }
}
