import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/attraction_controller.dart';
import '../models/attraction.dart';
import '../models/category.dart';
import '../models/google_place.dart';
import '../services/google_places_service.dart';
import 'admin_heritage_form_page.dart';
import 'admin_login_page.dart';
import 'admin_sidebar.dart';
import 'attraction_map_picker_page.dart';
import 'category_management_page.dart';

class AttractionFormPage extends StatefulWidget {
  final AttractionModel? attraction;

  const AttractionFormPage({
    super.key,
    this.attraction,
  });

  @override
  State<AttractionFormPage> createState() =>
      _AttractionFormPageState();
}

class _AttractionFormPageState extends State<AttractionFormPage> {
  static const Color mainGreen = Color(0xFF0B6B2B);
  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF667085);

  static const String _culturalHeritageCategoryId =
      'S8wzl7nxsXMZ73Zvtuhq';

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final AttractionController _controller = AttractionController();
  final GooglePlacesService _placesService = GooglePlacesService();

  final TextEditingController _googleSearchController =
  TextEditingController();

  late final TextEditingController _nameController;
  late final TextEditingController _areaController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _websiteController;

  late final TextEditingController _malaysianAdultController;
  late final TextEditingController _malaysianChildController;
  late final TextEditingController _malaysianSeniorController;
  late final TextEditingController _nonMalaysianAdultController;
  late final TextEditingController _nonMalaysianChildController;
  late final TextEditingController _nonMalaysianSeniorController;

  final Map<String, TextEditingController> _openingHoursControllers = {};

  String _googlePlaceId = '';
  List<GooglePlace> _googleResults = [];

  bool _isSearchingGoogle = false;
  bool _isLoadingGoogleDetails = false;
  String? _googleSearchError;

  final Set<String> _selectedCategoryIds = {};
  String? _primaryCategoryId;
  String? _selectedState;

  String _recommendedDuration = '1 - 2 hours';
  String _status = 'Active';
  bool _isFreeEntry = false;
  bool _isOpen24Hours = false;

  final Set<String> _selectedFacilities = {};
  final List<TextEditingController> _highlightControllers = [];

  final List<String> _existingImageUrls = [];
  String? _existingCoverUrl;

  bool get _isEdit => widget.attraction != null;

  final List<String> _facilityOptions = const [
    'Parking',
    'Public Toilet',
    'Prayer Room',
    'Wheelchair Accessible',
    'Food & Beverage',
    'Wi-Fi',
    'Souvenir Shop',
    'Information Counter',
  ];

  final List<String> _states = const [
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

  final List<String> _durationOptions = const [
    'Less than 1 hour',
    '1 - 2 hours',
    '2 - 3 hours',
    'Half Day',
    'Full Day',
  ];

  bool get _isExistingCulturalHeritage {
    final attraction = widget.attraction;

    if (attraction == null) {
      return false;
    }

    if (attraction.categoryId == _culturalHeritageCategoryId ||
        attraction.categoryName.trim().toLowerCase() ==
            'cultural & heritage') {
      return true;
    }

    if (attraction.categoryIds.contains(_culturalHeritageCategoryId)) {
      return true;
    }

    return attraction.categoryNames.any(
          (name) => name.trim().toLowerCase() == 'cultural & heritage',
    );
  }

  bool get _isCulturalHeritage {
    if (_selectedCategoryIds.contains(_culturalHeritageCategoryId)) {
      return true;
    }

    for (final category in _controller.categories) {
      if (_selectedCategoryIds.contains(category.id) &&
          category.name.trim().toLowerCase() == 'cultural & heritage') {
        return true;
      }
    }

    return _isExistingCulturalHeritage;
  }

  @override
  void initState() {
    super.initState();

    final attraction = widget.attraction;

    _nameController =
        TextEditingController(text: attraction?.name ?? '');
    _areaController =
        TextEditingController(text: attraction?.area ?? '');
    _descriptionController =
        TextEditingController(text: attraction?.description ?? '');
    _addressController =
        TextEditingController(text: attraction?.address ?? '');

    final latitude = attraction?.latitude ?? 0;
    final longitude = attraction?.longitude ?? 0;

    _latitudeController = TextEditingController(
      text: latitude == 0 ? '' : latitude.toStringAsFixed(6),
    );

    _longitudeController = TextEditingController(
      text: longitude == 0 ? '' : longitude.toStringAsFixed(6),
    );

    _phoneController =
        TextEditingController(text: attraction?.phoneNumber ?? '');
    _websiteController =
        TextEditingController(text: attraction?.websiteUrl ?? '');

    _malaysianAdultController =
        _feeController(attraction?.malaysianAdultFee);
    _malaysianChildController =
        _feeController(attraction?.malaysianChildFee);
    _malaysianSeniorController =
        _feeController(attraction?.malaysianSeniorFee);

    _nonMalaysianAdultController =
        _feeController(attraction?.nonMalaysianAdultFee);
    _nonMalaysianChildController =
        _feeController(attraction?.nonMalaysianChildFee);
    _nonMalaysianSeniorController =
        _feeController(attraction?.nonMalaysianSeniorFee);

    for (final day in _days) {
      final periods =
          attraction?.openingHours[day] ?? const <String>[];

      _openingHoursControllers[day] = TextEditingController(
        text: periods.join(', '),
      );
    }

    if (attraction != null) {
      _googlePlaceId = attraction.googlePlaceId;

      _selectedCategoryIds.addAll(
        attraction.categoryIds.isNotEmpty
            ? attraction.categoryIds
            : (attraction.categoryId.trim().isEmpty
            ? const <String>[]
            : <String>[attraction.categoryId]),
      );

      _primaryCategoryId = attraction.categoryId.trim().isNotEmpty
          ? attraction.categoryId
          : (_selectedCategoryIds.isEmpty
          ? null
          : _selectedCategoryIds.first);

      _selectedState = _states.contains(attraction.state)
          ? attraction.state
          : null;

      _recommendedDuration =
      _durationOptions.contains(attraction.recommendedDuration)
          ? attraction.recommendedDuration
          : '1 - 2 hours';

      _status =
      attraction.status == 'Inactive' ? 'Inactive' : 'Active';

      _isFreeEntry = attraction.isFreeEntry;
      _isOpen24Hours = attraction.isOpen24Hours;

      _selectedFacilities.addAll(attraction.facilities);
      _existingImageUrls.addAll(attraction.imageUrls);

      _existingCoverUrl = attraction.coverImageUrl.isEmpty
          ? (_existingImageUrls.isEmpty
          ? null
          : _existingImageUrls.first)
          : attraction.coverImageUrl;

      if (attraction.highlights.isEmpty) {
        _highlightControllers.add(TextEditingController());
      } else {
        _highlightControllers.addAll(
          attraction.highlights.map(
                (value) => TextEditingController(text: value),
          ),
        );
      }

      if (attraction.name.trim().isNotEmpty) {
        _googleSearchController.text = attraction.name;
      }
    } else {
      _highlightControllers.add(TextEditingController());
    }

    _controller.addListener(_refreshPage);
    _controller.loadCategories();
  }

  TextEditingController _feeController(double? value) {
    if (value == null || value == 0) {
      return TextEditingController();
    }

    return TextEditingController(
      text: value.toStringAsFixed(2),
    );
  }

  void _formatMoneyController(
      TextEditingController controller,
      ) {
    final raw = controller.text.trim();

    if (raw.isEmpty) {
      return;
    }

    final value = double.tryParse(raw);

    if (value == null) {
      return;
    }

    controller.text = value.toStringAsFixed(2);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _formatAllFees() {
    _formatMoneyController(_malaysianAdultController);
    _formatMoneyController(_malaysianChildController);
    _formatMoneyController(_malaysianSeniorController);
    _formatMoneyController(_nonMalaysianAdultController);
    _formatMoneyController(_nonMalaysianChildController);
    _formatMoneyController(_nonMalaysianSeniorController);
  }

  @override
  void dispose() {
    _controller.removeListener(_refreshPage);
    _controller.dispose();

    _googleSearchController.dispose();
    _nameController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();

    _malaysianAdultController.dispose();
    _malaysianChildController.dispose();
    _malaysianSeniorController.dispose();
    _nonMalaysianAdultController.dispose();
    _nonMalaysianChildController.dispose();
    _nonMalaysianSeniorController.dispose();

    for (final controller in _openingHoursControllers.values) {
      controller.dispose();
    }

    for (final controller in _highlightControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _refreshPage() {
    if (mounted) setState(() {});
  }

  Future<void> _searchGooglePlaces() async {
    final query = _googleSearchController.text.trim();

    if (query.isEmpty) {
      _showMessage(
        'Enter an attraction name first.',
        error: true,
      );
      return;
    }

    setState(() {
      _isSearchingGoogle = true;
      _googleSearchError = null;
      _googleResults = [];
    });

    try {
      final results = await _placesService.searchPlaces(
        '$query Malaysia',
      );

      if (!mounted) return;

      setState(() {
        _googleResults = results;
      });

      if (results.isEmpty) {
        _showMessage(
          'No matching Google Places found.',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _googleSearchError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingGoogle = false;
        });
      }
    }
  }

  Future<void> _selectGooglePlace(
      GooglePlace searchResult,
      ) async {
    setState(() {
      _isLoadingGoogleDetails = true;
      _googleSearchError = null;
    });

    try {
      final place = await _placesService.getPlaceDetails(
        searchResult.placeId,
      );

      if (!mounted) return;

      _applyGooglePlace(place);

      setState(() {
        _googleResults = [];
      });

      _showMessage('Google Place details imported.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to load Google Place details: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogleDetails = false;
        });
      }
    }
  }

  void _applyGooglePlace(GooglePlace place) {
    _googlePlaceId = place.placeId;

    _latitudeController.text =
    place.latitude == 0 ? '' : place.latitude.toStringAsFixed(6);

    _longitudeController.text =
    place.longitude == 0 ? '' : place.longitude.toStringAsFixed(6);

    _nameController.text = place.name;
    _addressController.text = place.address;

    if (place.phoneNumber.trim().isNotEmpty) {
      _phoneController.text = place.phoneNumber.trim();
    }

    if (place.websiteUrl.trim().isNotEmpty) {
      _websiteController.text = place.websiteUrl.trim();
    }

    if (_states.contains(place.state)) {
      _selectedState = place.state;
    }

    if (place.area.trim().isNotEmpty) {
      _areaController.text = place.area.trim();
    }

    for (final day in _days) {
      final periods =
          place.openingHours[day] ?? const <String>[];

      _openingHoursControllers[day]!.text =
          periods.join(', ');
    }

    _googleSearchController.text = place.name;

    final anyOpeningHour = place.openingHours.values
        .any((periods) => periods.isNotEmpty);

    _isOpen24Hours = !anyOpeningHour;

    setState(() {});
  }

  Map<String, List<String>> _buildOpeningHours() {
    final result = <String, List<String>>{};

    for (final day in _days) {
      final raw =
      _openingHoursControllers[day]!.text.trim();

      if (raw.isEmpty) {
        result[day] = <String>[];
        continue;
      }

      result[day] = raw
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    return result;
  }

  bool _validOpeningHours(
      Map<String, List<String>> value,
      ) {
    final format = RegExp(
      r'^(?:[01]\d|2[0-3]):[0-5]\d-(?:[01]\d|2[0-3]|24):[0-5]\d$',
    );

    for (final periods in value.values) {
      for (final period in periods) {
        if (!format.hasMatch(period)) {
          return false;
        }
      }
    }

    return true;
  }

  double? _parsedLatitude() {
    final value =
    double.tryParse(_latitudeController.text.trim());

    if (value == null || value < -90 || value > 90) {
      return null;
    }

    return value;
  }

  double? _parsedLongitude() {
    final value =
    double.tryParse(_longitudeController.text.trim());

    if (value == null || value < -180 || value > 180) {
      return null;
    }

    return value;
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<AttractionMapSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => AttractionMapPickerPage(
          initialLatitude: _parsedLatitude(),
          initialLongitude: _parsedLongitude(),
          initialSearchText: _addressController.text.trim(),
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _latitudeController.text =
          result.latitude.toStringAsFixed(6);
      _longitudeController.text =
          result.longitude.toStringAsFixed(6);

      if (_addressController.text.trim().isEmpty &&
          result.address != null &&
          result.address!.trim().isNotEmpty) {
        _addressController.text = result.address!.trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: Row(
        children: [
          AdminSidebar(
            selectedPage: 'attraction',
            onDashboardTap: () {
              Navigator.popUntil(
                context,
                    (route) => route.isFirst,
              );
            },
            onAttractionTap: () {
              Navigator.pop(context);
            },
            onCategoryTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const CategoryManagementPage(),
                ),
              );
            },
            onCulturalHeritageTap: () {
              // Cultural & Heritage information is managed inside
              // Attraction Management in the unified admin flow.
            },
            onStampTap: () {},
            onReportTap: () {},
            onLogoutTap: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const AdminLoginPage(),
                ),
                    (route) => false,
              );
            },
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _pageHeader(),
                          const SizedBox(height: 22),
                          _googlePlacesCard(),
                          const SizedBox(height: 20),
                          _basicInformation(),
                          const SizedBox(height: 20),
                          _visitInformation(),
                          const SizedBox(height: 20),
                          _locationContact(),
                          const SizedBox(height: 20),
                          _facilitySection(),
                          const SizedBox(height: 20),
                          _highlightSection(),
                          const SizedBox(height: 20),
                          _imageSection(),
                          const SizedBox(height: 20),
                          _statusSection(),
                          const SizedBox(height: 24),
                          _bottomActions(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_controller.isProcessing ||
                    _isLoadingGoogleDetails)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: mainGreen,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _controller.isProcessing
              ? null
              : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit
                    ? 'Edit Attraction'
                    : 'Add New Attraction',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                !_isEdit && _isCulturalHeritage
                    ? 'Step 1 of 2: Complete the attraction details, then click Next.'
                    : _isEdit
                    ? 'Update attraction and EcoTravel information.'
                    : 'Use Google Place to auto-fill details, upload one attraction image, then save.',
                style: const TextStyle(
                  fontSize: 13,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),

        // Existing Cultural & Heritage attractions edit their
        // heritage-specific information separately.
        if (_isEdit && _isExistingCulturalHeritage) ...[
          const SizedBox(width: 18),
          ElevatedButton.icon(
            onPressed: _controller.isProcessing
                ? null
                : _openCulturalInformation,
            style: ElevatedButton.styleFrom(
              backgroundColor: mainGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            icon: const Icon(
              Icons.account_balance_outlined,
              size: 19,
            ),
            label: const Text(
              'Edit Cultural Information',
            ),
          ),
        ],
      ],
    );
  }

  Widget _googlePlacesCard() {
    final connected = _googlePlaceId.trim().isNotEmpty;

    return _sectionCard(
      title: 'Google Place',
      subtitle:
      'Optional: search Google to auto-fill place information. Images are selected separately in EcoTravel Images.',
      icon: Icons.travel_explore_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                controller: _googleSearchController,
                enabled: !_controller.isProcessing &&
                    !_isLoadingGoogleDetails,
                onSubmitted: (_) => _searchGooglePlaces(),
                decoration: _inputDecoration(
                  hint: 'e.g. Petronas Twin Towers',
                ).copyWith(
                  prefixIcon: const Icon(Icons.search),
                ),
              );

              final button = SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSearchingGoogle ||
                      _isLoadingGoogleDetails
                      ? null
                      : _searchGooglePlaces,
                  icon: _isSearchingGoogle
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.search, size: 18),
                  label: Text(
                    _isSearchingGoogle
                        ? 'Searching...'
                        : 'Search Google',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              );

              if (constraints.maxWidth < 700) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: button,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 10),
                  button,
                ],
              );
            },
          ),
          if (_googleSearchError != null) ...[
            const SizedBox(height: 10),
            Text(
              _googleSearchError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 11,
              ),
            ),
          ],
          if (_googleResults.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _googleResults.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _googleResults[index];

                  return ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: mainGreen,
                    ),
                    title: Text(
                      place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: OutlinedButton(
                      onPressed: _isLoadingGoogleDetails
                          ? null
                          : () => _selectGooglePlace(place),
                      child: const Text('Select'),
                    ),
                  );
                },
              ),
            ),
          ],
          if (connected) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: mainGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Google Place connected • $_googlePlaceId',
                      style: const TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _basicInformation() {
    return _sectionCard(
      title: 'Basic Information',
      subtitle:
      'Select multiple categories and choose one primary category.',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldBlock(
            'Attraction Name',
            _textField(
              controller: _nameController,
              hint: 'Attraction name',
              maxLength: 100,
            ),
            required: true,
          ),
          const SizedBox(height: 18),
          _label('Categories', required: true),
          const SizedBox(height: 8),
          _categoryMultiSelect(),
          if (_selectedCategoryIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            _primaryCategoryDropdown(),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;

              final state = _fieldBlock(
                'State',
                _stateDropdown(),
                required: true,
              );

              final area = _fieldBlock(
                'Area',
                _textField(
                  controller: _areaController,
                  hint: 'e.g. KLCC',
                  maxLength: 80,
                ),
                required: true,
              );

              if (compact) {
                return Column(
                  children: [
                    state,
                    const SizedBox(height: 16),
                    area,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: state),
                  const SizedBox(width: 16),
                  Expanded(child: area),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _fieldBlock(
            'Description',
            _textField(
              controller: _descriptionController,
              hint:
              'Enter EcoTravel attraction description...',
              maxLines: 5,
              maxLength: 1000,
            ),
            required: true,
          ),
        ],
      ),
    );
  }

  Widget _visitInformation() {
    return _sectionCard(
      title: 'Visit Information',
      subtitle:
      'Weekly opening hours can be auto-filled from Google and edited by Admin.',
      icon: Icons.schedule_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isOpen24Hours,
            activeColor: mainGreen,
            title: const Text(
              'Open 24 Hours',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Enable this when the attraction has no closing time.',
            ),
            onChanged: _controller.isProcessing
                ? null
                : (value) {
              setState(() {
                _isOpen24Hours = value;
              });
            },
          ),
          if (!_isOpen24Hours) ...[
            const SizedBox(height: 8),
            _weeklyOpeningHoursEditor(),
          ],
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 18),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _isFreeEntry,
            activeColor: mainGreen,
            title: const Text(
              'Free Entry',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Enable this if no entry fee is required.',
            ),
            onChanged: _controller.isProcessing
                ? null
                : (value) {
              setState(() {
                _isFreeEntry = value ?? false;

                if (_isFreeEntry) {
                  _clearAllFees();
                }
              });
            },
          ),
          if (!_isFreeEntry) ...[
            const SizedBox(height: 12),
            _priceGroup(
              title: 'Malaysian',
              adultController: _malaysianAdultController,
              childController: _malaysianChildController,
              seniorController: _malaysianSeniorController,
            ),
            const SizedBox(height: 16),
            _priceGroup(
              title: 'Non-Malaysian',
              adultController: _nonMalaysianAdultController,
              childController: _nonMalaysianChildController,
              seniorController: _nonMalaysianSeniorController,
            ),
          ],
          const SizedBox(height: 18),
          _fieldBlock(
            'Recommended Sightseeing Time',
            _durationDropdown(),
            required: true,
          ),
        ],
      ),
    );
  }

  Widget _weeklyOpeningHoursEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opening Hours',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Format: HH:mm-HH:mm. Split hours can use commas, e.g. 10:00-13:00, 14:00-18:00. Blank day = Closed.',
          style: TextStyle(
            fontSize: 11,
            color: secondaryText,
          ),
        ),
        const SizedBox(height: 14),
        ..._days.map(
              (day) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _openingHoursControllers[day],
                    enabled: !_controller.isProcessing,
                    decoration: _inputDecoration(
                      hint: '10:00-18:00',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationContact() {
    return _sectionCard(
      title: 'Location & Contact',
      subtitle:
      'Google can auto-fill these fields, or Admin can enter them manually.',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldBlock(
            'Full Address',
            _textField(
              controller: _addressController,
              hint: 'Full attraction address',
              maxLines: 3,
              maxLength: 250,
            ),
            required: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Map Coordinates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _controller.isProcessing
                    ? null
                    : _openMapPicker,
                style: OutlinedButton.styleFrom(
                  foregroundColor: mainGreen,
                  side: const BorderSide(
                    color: mainGreen,
                  ),
                ),
                icon: const Icon(
                  Icons.map_outlined,
                  size: 18,
                ),
                label: const Text('Find on Map'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;

              final latitude = _fieldBlock(
                'Latitude',
                _coordinateField(
                  controller: _latitudeController,
                  hint: 'e.g. 5.414130',
                  isLatitude: true,
                ),
                required: true,
              );

              final longitude = _fieldBlock(
                'Longitude',
                _coordinateField(
                  controller: _longitudeController,
                  hint: 'e.g. 100.328750',
                  isLatitude: false,
                ),
                required: true,
              );

              if (compact) {
                return Column(
                  children: [
                    latitude,
                    const SizedBox(height: 16),
                    longitude,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: latitude),
                  const SizedBox(width: 16),
                  Expanded(child: longitude),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;

              final phone = _fieldBlock(
                'Phone Number',
                _textField(
                  controller: _phoneController,
                  hint: 'e.g. +60323318080',
                  maxLength: 30,
                ),
              );

              final website = _fieldBlock(
                'Website',
                _textField(
                  controller: _websiteController,
                  hint: 'https://example.com',
                  maxLength: 300,
                ),
              );

              if (compact) {
                return Column(
                  children: [
                    phone,
                    const SizedBox(height: 16),
                    website,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: phone),
                  const SizedBox(width: 16),
                  Expanded(child: website),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _facilitySection() {
    return _sectionCard(
      title: 'Facilities Provided',
      subtitle:
      'Select facilities available at this attraction.',
      icon: Icons.accessible_forward_outlined,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _facilityOptions.map(
              (facility) {
            final selected =
            _selectedFacilities.contains(facility);

            return FilterChip(
              label: Text(facility),
              selected: selected,
              selectedColor: mainGreen.withOpacity(0.08),
              checkmarkColor: mainGreen,
              side: BorderSide(
                color: selected ? mainGreen : borderColor,
              ),
              onSelected: _controller.isProcessing
                  ? null
                  : (value) {
                setState(() {
                  if (value) {
                    _selectedFacilities.add(facility);
                  } else {
                    _selectedFacilities.remove(facility);
                  }
                });
              },
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _highlightSection() {
    return _sectionCard(
      title: 'Highlights',
      subtitle:
      'Add key experiences or special features.',
      icon: Icons.star_outline,
      child: Column(
        children: [
          for (int i = 0;
          i < _highlightControllers.length;
          i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _highlightControllers[i],
                      hint: 'e.g. Panoramic city views',
                      maxLength: 120,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _controller.isProcessing
                        ? null
                        : () => _removeHighlight(i),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _controller.isProcessing
                  ? null
                  : _addHighlight,
              icon: const Icon(Icons.add),
              label: const Text('Add Highlight'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSingleAttractionImage() async {
    await _controller.pickImages();

    if (!mounted) {
      return;
    }

    // A newly selected image replaces old images in this form.
    // Existing Storage files are only deleted after Save succeeds.
    if (_controller.selectedImages.isNotEmpty) {
      setState(() {
        _existingImageUrls.clear();
        _existingCoverUrl = null;
      });
    }
  }

  Widget _imageSection() {
    final newImages = _controller.selectedImages;

    return _sectionCard(
      title: 'EcoTravel Images',
      subtitle:
      'Choose one attraction image. It will be uploaded to Firebase Storage when you save.',
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_existingImageUrls.isNotEmpty) ...[
            const Text(
              'Existing Firebase Images',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _existingImageUrls
                  .map(_existingImageCard)
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          InkWell(
            onTap: _controller.isProcessing
                ? null
                : _pickSingleAttractionImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFD0D5DD),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 38,
                    color: mainGreen,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click to choose an attraction image',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (newImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                newImages.length,
                    (index) => _newImageCard(
                  bytes: newImages[index].bytes,
                  index: index,
                  isCover: _existingCoverUrl == null &&
                      _controller.coverImageIndex == index,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _existingImageCard(String url) {
    final isCover = _existingCoverUrl == url;

    return _imageCardShell(
      isCover: isCover,
      image: Image.network(
        url,
        width: 215,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 215,
          height: 140,
          color: const Color(0xFFF2F4F7),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
      onRemove: () {
        setState(() {
          _existingImageUrls.remove(url);

          if (_existingCoverUrl == url) {
            _existingCoverUrl = _existingImageUrls.isEmpty
                ? null
                : _existingImageUrls.first;
          }
        });
      },
      onSetCover: isCover
          ? null
          : () {
        setState(() {
          _existingCoverUrl = url;
        });
      },
    );
  }

  Widget _newImageCard({
    required Uint8List bytes,
    required int index,
    required bool isCover,
  }) {
    return _imageCardShell(
      isCover: isCover,
      image: Image.memory(
        bytes,
        width: 215,
        height: 140,
        fit: BoxFit.cover,
      ),
      onRemove: () => _controller.removeImage(index),
      onSetCover: isCover
          ? null
          : () {
        setState(() {
          _existingCoverUrl = null;
        });
        _controller.setCoverImage(index);
      },
    );
  }

  Widget _imageCardShell({
    required Widget image,
    required bool isCover,
    required VoidCallback onRemove,
    VoidCallback? onSetCover,
  }) {
    return SizedBox(
      width: 215,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: image,
              ),
              if (isCover)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: Chip(
                    label: Text('Cover'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  onPressed: onRemove,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (onSetCover != null)
            TextButton(
              onPressed: onSetCover,
              child: const Text('Set as cover'),
            ),
        ],
      ),
    );
  }

  Widget _statusSection() {
    return _sectionCard(
      title: 'Status',
      subtitle:
      'Choose whether this attraction is visible to users.',
      icon: Icons.toggle_on_outlined,
      child: Wrap(
        spacing: 10,
        children: [
          ChoiceChip(
            label: const Text('Active'),
            selected: _status == 'Active',
            onSelected: _controller.isProcessing
                ? null
                : (_) {
              setState(() {
                _status = 'Active';
              });
            },
          ),
          ChoiceChip(
            label: const Text('Inactive'),
            selected: _status == 'Inactive',
            onSelected: _controller.isProcessing
                ? null
                : (_) {
              setState(() {
                _status = 'Inactive';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 550;

        final cancel = SizedBox(
          width: compact ? double.infinity : 130,
          height: 50,
          child: OutlinedButton(
            onPressed: _controller.isProcessing
                ? null
                : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );

        final save = SizedBox(
          width: compact ? double.infinity : 190,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _controller.isProcessing
                ? null
                : () => _saveAttraction(
              openHeritageAfterSave:
              !_isEdit && _isCulturalHeritage,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainGreen,
              foregroundColor: Colors.white,
            ),
            icon: _controller.isProcessing
                ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Icon(
              !_isEdit && _isCulturalHeritage
                  ? Icons.arrow_forward
                  : Icons.save,
            ),
            label: Text(
              _controller.isProcessing
                  ? 'Saving...'
                  : (!_isEdit && _isCulturalHeritage
                  ? 'Next'
                  : (_isEdit
                  ? 'Save Changes'
                  : 'Add Attraction')),
            ),
          ),
        );

        if (compact) {
          return Column(
            children: [
              cancel,
              const SizedBox(height: 10),
              save,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            cancel,
            const SizedBox(width: 10),
            save,
          ],
        );
      },
    );
  }

  Future<void> _saveAttraction({
    bool openHeritageAfterSave = false,
  }) async {
    _formatAllFees();

    final name = _nameController.text.trim();
    final area = _areaController.text.trim();
    final description = _descriptionController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final website = _websiteController.text.trim();

    final latitude = _parsedLatitude();
    final longitude = _parsedLongitude();

    if (name.isEmpty ||
        _selectedCategoryIds.isEmpty ||
        _primaryCategoryId == null ||
        _selectedState == null ||
        area.isEmpty ||
        description.isEmpty ||
        address.isEmpty ||
        latitude == null ||
        longitude == null) {
      _showMessage(
        'Please complete all required fields.',
        error: true,
      );
      return;
    }

    if (name.length < 3) {
      _showMessage(
        'Attraction name must contain at least 3 characters.',
        error: true,
      );
      return;
    }

    if (description.length < 20) {
      _showMessage(
        'Description must contain at least 20 characters.',
        error: true,
      );
      return;
    }

    if (website.isNotEmpty) {
      final uri = Uri.tryParse(website);

      if (uri == null ||
          !(uri.isScheme('http') ||
              uri.isScheme('https'))) {
        _showMessage(
          'Website must start with http:// or https://.',
          error: true,
        );
        return;
      }
    }

    final openingHours = _buildOpeningHours();

    if (!_isOpen24Hours &&
        !_validOpeningHours(openingHours)) {
      _showMessage(
        'Opening hours must use HH:mm-HH:mm format.',
        error: true,
      );
      return;
    }

    final primaryCategory =
    _findCategory(_primaryCategoryId!);

    if (primaryCategory == null) {
      _showMessage(
        'Please select a valid primary category.',
        error: true,
      );
      return;
    }

    final selectedCategories = _controller.categories
        .where(
          (category) =>
          _selectedCategoryIds.contains(category.id),
    )
        .toList();

    final categoryIds =
    selectedCategories.map((item) => item.id).toList();

    final categoryNames =
    selectedCategories.map((item) => item.name).toList();

    final highlights = _highlightControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (_existingImageUrls.isEmpty &&
        _controller.selectedImages.isEmpty) {
      _showMessage(
        'Please upload at least one attraction image.',
        error: true,
      );
      return;
    }

    double money(TextEditingController controller) {
      return double.tryParse(controller.text.trim()) ?? 0;
    }

    final malaysianAdultFee = money(_malaysianAdultController);
    final malaysianChildFee = money(_malaysianChildController);
    final malaysianSeniorFee = money(_malaysianSeniorController);

    final nonMalaysianAdultFee =
    money(_nonMalaysianAdultController);
    final nonMalaysianChildFee =
    money(_nonMalaysianChildController);
    final nonMalaysianSeniorFee =
    money(_nonMalaysianSeniorController);

    bool success;

    if (_isEdit) {
      final original = widget.attraction!;
      final removedUrls = original.imageUrls
          .where((url) => !_existingImageUrls.contains(url))
          .toList();

      success = await _controller.updateAttraction(
        original: original,
        googlePlaceId: _googlePlaceId,
        latitude: latitude,
        longitude: longitude,
        openingHours:
        _isOpen24Hours ? const {} : openingHours,
        isOpen24Hours: _isOpen24Hours,
        websiteUrl: website,
        name: name,
        categoryId: primaryCategory.id,
        categoryName: primaryCategory.name,
        categoryIds: categoryIds,
        categoryNames: categoryNames,
        state: _selectedState!,
        area: area,
        description: description,
        isFreeEntry: _isFreeEntry,
        malaysianAdultFee: malaysianAdultFee,
        malaysianChildFee: malaysianChildFee,
        malaysianSeniorFee: malaysianSeniorFee,
        nonMalaysianAdultFee: nonMalaysianAdultFee,
        nonMalaysianChildFee: nonMalaysianChildFee,
        nonMalaysianSeniorFee: nonMalaysianSeniorFee,
        recommendedDuration: _recommendedDuration,
        address: address,
        phoneNumber: phone,
        facilities: _selectedFacilities.toList(),
        highlights: highlights,
        existingImageUrls: _existingImageUrls,
        selectedExistingCoverUrl: _existingCoverUrl,
        status: _status,
      );

      if (success) {
        for (final url in removedUrls) {
          await _controller.deleteStorageImage(url);
        }
      }
    } else {
      success = await _controller.addAttraction(
        googlePlaceId: _googlePlaceId,
        latitude: latitude,
        longitude: longitude,
        openingHours:
        _isOpen24Hours ? const {} : openingHours,
        isOpen24Hours: _isOpen24Hours,
        websiteUrl: website,
        name: name,
        categoryId: primaryCategory.id,
        categoryName: primaryCategory.name,
        categoryIds: categoryIds,
        categoryNames: categoryNames,
        state: _selectedState!,
        area: area,
        description: description,
        isFreeEntry: _isFreeEntry,
        malaysianAdultFee: malaysianAdultFee,
        malaysianChildFee: malaysianChildFee,
        malaysianSeniorFee: malaysianSeniorFee,
        nonMalaysianAdultFee: nonMalaysianAdultFee,
        nonMalaysianChildFee: nonMalaysianChildFee,
        nonMalaysianSeniorFee: nonMalaysianSeniorFee,
        recommendedDuration: _recommendedDuration,
        address: address,
        phoneNumber: phone,
        facilities: _selectedFacilities.toList(),
        highlights: highlights,
        status: _status,
      );
    }

    if (!mounted) return;

    if (!success) {
      _showMessage(
        'Unable to save attraction. Please check the entered information or duplicate attraction.',
        error: true,
      );
      return;
    }

    String? savedAttractionId;

    if (_isEdit) {
      savedAttractionId = widget.attraction!.id;
    } else {
      // Preferred source: the controller records the document ID
      // immediately after creating the attraction.
      savedAttractionId = _controller.lastSavedAttractionId;

      // Fallback for compatibility if the controller ID is unavailable.
      if (savedAttractionId == null || savedAttractionId.isEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('attractions')
            .where(
          'name',
          isEqualTo: name,
        )
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          savedAttractionId = snapshot.docs.first.id;
        }
      }
    }

    if (!mounted) return;

    if (openHeritageAfterSave && _isCulturalHeritage) {
      if (savedAttractionId == null || savedAttractionId.isEmpty) {
        _showMessage(
          'Attraction was saved, but its document ID could not be found. '
              'Open Edit Attraction and try Add Cultural Information again.',
          error: true,
        );

        Navigator.pop(context, true);
        return;
      }

      _showMessage(
        'Attraction added. Continue with cultural information.',
      );

      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AdminHeritageFormPage(
            attractionId: savedAttractionId!,
          ),
        ),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
      return;
    }

    _showMessage(
      _isEdit
          ? 'Attraction updated successfully.'
          : 'Attraction added successfully.',
    );

    Navigator.pop(context, true);
  }

  Future<void> _openCulturalInformation() async {
    if (!_isEdit || !_isExistingCulturalHeritage) {
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminHeritageFormPage(
          attractionId: widget.attraction!.id,
        ),
      ),
    );
  }

  Widget _categoryMultiSelect() {
    if (_controller.categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Text(
          'No active categories available.',
          style: TextStyle(
            fontSize: 12,
            color: secondaryText,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _controller.categories.map(
            (category) {
          final selected =
          _selectedCategoryIds.contains(category.id);

          return FilterChip(
            label: Text(category.name),
            selected: selected,
            selectedColor: mainGreen.withOpacity(0.08),
            checkmarkColor: mainGreen,
            side: BorderSide(
              color: selected ? mainGreen : borderColor,
            ),
            onSelected: _controller.isProcessing
                ? null
                : (value) {
              setState(() {
                if (value) {
                  _selectedCategoryIds.add(category.id);
                  _primaryCategoryId ??= category.id;
                } else {
                  _selectedCategoryIds.remove(category.id);

                  if (_primaryCategoryId == category.id) {
                    _primaryCategoryId =
                    _selectedCategoryIds.isEmpty
                        ? null
                        : _selectedCategoryIds.first;
                  }
                }
              });
            },
          );
        },
      ).toList(),
    );
  }

  Widget _primaryCategoryDropdown() {
    final selected = _controller.categories
        .where(
          (item) => _selectedCategoryIds.contains(item.id),
    )
        .toList();

    if (selected.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_primaryCategoryId == null ||
        !_selectedCategoryIds.contains(_primaryCategoryId)) {
      _primaryCategoryId = selected.first.id;
    }

    return _fieldBlock(
      'Primary Category',
      DropdownButtonFormField<String>(
        value: _primaryCategoryId,
        isExpanded: true,
        decoration: _inputDecoration(
          hint: 'Select primary category',
        ),
        items: selected
            .map(
              (item) => DropdownMenuItem<String>(
            value: item.id,
            child: Text(item.name),
          ),
        )
            .toList(),
        onChanged: _controller.isProcessing
            ? null
            : (value) {
          setState(() {
            _primaryCategoryId = value;
          });
        },
      ),
      required: true,
    );
  }

  CategoryModel? _findCategory(String id) {
    for (final category in _controller.categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Widget _stateDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedState,
      isExpanded: true,
      decoration: _inputDecoration(
        hint: 'Select state',
      ),
      items: _states
          .map(
            (state) => DropdownMenuItem<String>(
          value: state,
          child: Text(state),
        ),
      )
          .toList(),
      onChanged: _controller.isProcessing
          ? null
          : (value) {
        setState(() {
          _selectedState = value;
        });
      },
    );
  }

  Widget _durationDropdown() {
    return DropdownButtonFormField<String>(
      value: _recommendedDuration,
      isExpanded: true,
      decoration: _inputDecoration(
        hint: 'Select duration',
      ),
      items: _durationOptions
          .map(
            (value) => DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        ),
      )
          .toList(),
      onChanged: _controller.isProcessing
          ? null
          : (value) {
        if (value == null) return;

        setState(() {
          _recommendedDuration = value;
        });
      },
    );
  }

  Widget _priceGroup({
    required String title,
    required TextEditingController adultController,
    required TextEditingController childController,
    required TextEditingController seniorController,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _moneyField(
                  label: 'Adult',
                  controller: adultController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _moneyField(
                  label: 'Child',
                  controller: childController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _moneyField(
                  label: 'Senior Citizen',
                  controller: seniorController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled:
          !_isFreeEntry &&
              !_controller.isProcessing,
          keyboardType:
          const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d{0,4}(\.\d{0,2})?'),
            ),
          ],
          onEditingComplete: () {
            _formatMoneyController(controller);
            FocusScope.of(context).unfocus();
          },
          onTapOutside: (_) {
            _formatMoneyController(controller);
            FocusScope.of(context).unfocus();
          },
          decoration:
          _inputDecoration(hint: '0.00').copyWith(
            prefixText: 'RM ',
          ),
        ),
      ],
    );
  }

  Widget _coordinateField({
    required TextEditingController controller,
    required String hint,
    required bool isLatitude,
  }) {
    return TextField(
      controller: controller,
      enabled: !_controller.isProcessing,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'^-?\d{0,3}(\.\d{0,8})?'),
        ),
      ],
      decoration: _inputDecoration(hint: hint).copyWith(
        helperText: isLatitude
            ? 'Valid range: -90 to 90'
            : 'Valid range: -180 to 180',
        helperStyle: const TextStyle(
          fontSize: 10,
          color: secondaryText,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      enabled: !_controller.isProcessing,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: _inputDecoration(hint: hint),
    );
  }

  Widget _fieldBlock(
      String label,
      Widget child, {
        bool required = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        const SizedBox(height: 7),
        child,
      ],
    );
  }

  Widget _label(
      String text, {
        bool required = false,
      }) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 12,
      ),
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(
          color: mainGreen,
          width: 1.4,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: borderColor),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: mainGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: mainGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  void _clearAllFees() {
    _malaysianAdultController.clear();
    _malaysianChildController.clear();
    _malaysianSeniorController.clear();
    _nonMalaysianAdultController.clear();
    _nonMalaysianChildController.clear();
    _nonMalaysianSeniorController.clear();
  }

  void _addHighlight() {
    setState(() {
      _highlightControllers.add(TextEditingController());
    });
  }

  void _removeHighlight(int index) {
    if (index < 0 || index >= _highlightControllers.length) {
      return;
    }

    setState(() {
      final controller = _highlightControllers.removeAt(index);
      controller.dispose();

      if (_highlightControllers.isEmpty) {
        _highlightControllers.add(TextEditingController());
      }
    });
  }

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : mainGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
