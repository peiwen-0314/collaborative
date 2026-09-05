import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/attraction_controller.dart';
import '../models/attraction.dart';
import '../models/category.dart';
import 'admin_sidebar.dart';
import 'admin_heritage_form_page.dart';
import 'attraction_map_picker_page.dart';

class AttractionFormPage extends StatefulWidget {
  final AttractionModel? attraction;

  const AttractionFormPage({
    super.key,
    this.attraction,
  });

  @override
  State<AttractionFormPage> createState() => _AttractionFormPageState();
}

class _AttractionFormPageState extends State<AttractionFormPage> {
  static const Color mainGreen = Color(0xFF0B6B2B);
  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF667085);

  final AttractionController _controller = AttractionController();

  late final TextEditingController _nameController;
  late final TextEditingController _areaController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _phoneController;

  late final TextEditingController _malaysianAdultController;
  late final TextEditingController _malaysianChildController;
  late final TextEditingController _malaysianSeniorController;
  late final TextEditingController _nonMalaysianAdultController;
  late final TextEditingController _nonMalaysianChildController;
  late final TextEditingController _nonMalaysianSeniorController;

  String? _selectedCategoryId;
  String? _selectedState;
  String _recommendedDuration = '1 - 2 hours';
  String _status = 'Active';
  bool _isFreeEntry = false;
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;

  final Set<String> _selectedFacilities = {};
  final List<TextEditingController> _highlightControllers = [];
  final List<String> _existingImageUrls = [];
  String? _existingCoverUrl;

  bool get _isEdit => widget.attraction != null;

  static const String _culturalHeritageCategoryId =
      'S8wzl7nxsXMZ73Zvtuhq';

  bool get _isExistingCulturalHeritage {
    final attraction = widget.attraction;

    if (attraction == null) {
      return false;
    }

    return attraction.categoryId ==
        _culturalHeritageCategoryId ||
        attraction.categoryName
            .trim()
            .toLowerCase() ==
            'cultural & heritage';
  }

  bool get _isCulturalHeritage {
    if (_selectedCategoryId ==
        _culturalHeritageCategoryId) {
      return true;
    }

    for (final category in _controller.categories) {
      if (category.id == _selectedCategoryId &&
          category.name
              .trim()
              .toLowerCase() ==
              'cultural & heritage') {
        return true;
      }
    }

    return widget.attraction?.categoryName
        .trim()
        .toLowerCase() ==
        'cultural & heritage';
  }

  final List<String> _facilityOptions = [
    'Parking',
    'Public Toilet',
    'Prayer Room',
    'Wheelchair Accessible',
    'Food & Beverage',
    'Wi-Fi',
    'Souvenir Shop',
    'Information Counter',
  ];

  final List<String> _states = [
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

  final List<String> _durationOptions = [
    'Less than 1 hour',
    '1 - 2 hours',
    '2 - 3 hours',
    'Half Day',
    'Full Day',
  ];

  @override
  void initState() {
    super.initState();

    final attraction = widget.attraction;

    _nameController = TextEditingController(text: attraction?.name ?? '');
    _areaController = TextEditingController(text: attraction?.area ?? '');
    _descriptionController =
        TextEditingController(text: attraction?.description ?? '');
    _addressController = TextEditingController(text: attraction?.address ?? '');

    final latitude = attraction?.latitude ?? 0;
    final longitude = attraction?.longitude ?? 0;

    _latitudeController = TextEditingController(
      text: latitude == 0
          ? ''
          : latitude.toStringAsFixed(6),
    );
    _longitudeController = TextEditingController(
      text: longitude == 0
          ? ''
          : longitude.toStringAsFixed(6),
    );

    final storedPhone = attraction?.phoneNumber ?? '';
    _phoneController = TextEditingController(
      text: storedPhone.startsWith('+60') ? storedPhone.substring(3) : storedPhone,
    );

    _malaysianAdultController = _feeController(attraction?.malaysianAdultFee);
    _malaysianChildController = _feeController(attraction?.malaysianChildFee);
    _malaysianSeniorController = _feeController(attraction?.malaysianSeniorFee);
    _nonMalaysianAdultController =
        _feeController(attraction?.nonMalaysianAdultFee);
    _nonMalaysianChildController =
        _feeController(attraction?.nonMalaysianChildFee);
    _nonMalaysianSeniorController =
        _feeController(attraction?.nonMalaysianSeniorFee);

    if (attraction != null) {
      _selectedCategoryId = attraction.categoryId;
      _selectedState = _states.contains(attraction.state) ? attraction.state : null;
      _recommendedDuration = _durationOptions.contains(attraction.recommendedDuration)
          ? attraction.recommendedDuration
          : '1 - 2 hours';
      _status = attraction.status == 'Inactive' ? 'Inactive' : 'Active';
      _isFreeEntry = attraction.isFreeEntry;
      _openingTime = _parseTime(attraction.openingTime);
      _closingTime = _parseTime(attraction.closingTime);
      _selectedFacilities.addAll(attraction.facilities);
      _existingImageUrls.addAll(attraction.imageUrls);
      _existingCoverUrl = attraction.coverImageUrl.isEmpty
          ? (_existingImageUrls.isEmpty ? null : _existingImageUrls.first)
          : attraction.coverImageUrl;

      if (attraction.highlights.isEmpty) {
        _highlightControllers.add(TextEditingController());
      } else {
        _highlightControllers.addAll(
          attraction.highlights.map((value) => TextEditingController(text: value)),
        );
      }
    } else {
      _highlightControllers.add(TextEditingController());
    }

    _controller.addListener(_refreshPage);
    _controller.loadCategories();
  }

  TextEditingController _feeController(double? value) {
    if (value == null || value == 0) return TextEditingController();
    return TextEditingController(text: value.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.removeListener(_refreshPage);
    _controller.dispose();

    _nameController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _phoneController.dispose();
    _malaysianAdultController.dispose();
    _malaysianChildController.dispose();
    _malaysianSeniorController.dispose();
    _nonMalaysianAdultController.dispose();
    _nonMalaysianChildController.dispose();
    _nonMalaysianSeniorController.dispose();

    for (final controller in _highlightControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _refreshPage() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: Row(
        children: [
          AdminSidebar(
            selectedPage: 'attraction',
            onDashboardTap: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            onAttractionTap: () => Navigator.pop(context),
            onCategoryTap: () {},
            onCulturalHeritageTap: () {
              // Cultural information is managed from
              // Attraction Management now.
            },
            onStampTap: () {},
            onReportTap: () {},
            onLogoutTap: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pageHeader(),
                          const SizedBox(height: 22),
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
                if (_controller.isProcessing)
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
          onPressed:
          _controller.isProcessing
              ? null
              : () =>
              Navigator.pop(
                context,
              ),
          icon:
          const Icon(
            Icons.arrow_back,
          ),
          tooltip: 'Back',
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit
                    ? 'Edit Attraction'
                    : 'Add New Attraction',
                style:
                const TextStyle(
                  fontSize: 28,
                  fontWeight:
                  FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                !_isEdit &&
                    _isCulturalHeritage
                    ? 'Step 1 of 2: Complete the attraction details, then click Next.'
                    : _isEdit
                    ? 'Update attraction details, visitor information and images.'
                    : 'Add attraction details, visitor information and images.',
                style:
                const TextStyle(
                  fontSize: 13,
                  color:
                  secondaryText,
                ),
              ),
            ],
          ),
        ),

        // When editing an existing Cultural & Heritage attraction,
        // cultural information is edited separately from the
        // normal Attraction form.
        if (_isEdit &&
            _isExistingCulturalHeritage) ...[
          const SizedBox(width: 18),
          ElevatedButton.icon(
            onPressed:
            _controller.isProcessing
                ? null
                : _openCulturalInformation,
            style:
            ElevatedButton.styleFrom(
              backgroundColor:
              mainGreen,
              foregroundColor:
              Colors.white,
              elevation: 0,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  7,
                ),
              ),
            ),
            icon:
            const Icon(
              Icons
                  .account_balance_outlined,
              size: 19,
            ),
            label:
            const Text(
              'Edit Cultural Information',
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openCulturalInformation() async {
    if (!_isEdit ||
        !_isExistingCulturalHeritage) {
      return;
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminHeritageFormPage(
              attractionId:
              widget.attraction!.id,
            ),
      ),
    );
  }

  Widget _basicInformation() {
    return _sectionCard(
      title: 'Basic Information',
      subtitle: 'Enter the basic details of the attraction.',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Attraction Name', required: true),
          _textField(
            controller: _nameController,
            hint: 'e.g. Petronas Twin Towers',
            maxLength: 100,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;
              final category = _fieldBlock(
                'Category',
                _categoryDropdown(),
                required: true,
              );
              final state = _fieldBlock(
                'State',
                _stateDropdown(),
                required: true,
              );
              final area = _fieldBlock(
                'Area',
                _textField(
                  controller: _areaController,
                  hint: 'e.g. Kuala Lumpur City Centre',
                  maxLength: 80,
                ),
                required: true,
              );

              if (compact) {
                return Column(
                  children: [
                    category,
                    const SizedBox(height: 16),
                    state,
                    const SizedBox(height: 16),
                    area,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: category),
                  const SizedBox(width: 16),
                  Expanded(child: state),
                  const SizedBox(width: 16),
                  Expanded(child: area),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _label('Description', required: true),
          _textField(
            controller: _descriptionController,
            hint: 'Enter a description of this attraction...',
            maxLines: 5,
            maxLength: 1000,
          ),
        ],
      ),
    );
  }

  Widget _visitInformation() {
    return _sectionCard(
      title: 'Visit Information',
      subtitle:
      'Set Malaysian and non-Malaysian entry fees, opening hours and visit duration.',
      icon: Icons.schedule_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isFreeEntry,
                  activeColor: mainGreen,
                  onChanged: _controller.isProcessing
                      ? null
                      : (value) {
                    setState(() {
                      _isFreeEntry = value ?? false;
                      if (_isFreeEntry) _clearAllFees();
                    });
                  },
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Entry',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enable this if no entry fee is required for all visitors.',
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 800;

              final opening = _fieldBlock(
                'Opening Time',
                _timeField(
                  value: _openingTime,
                  placeholder: 'Select opening time',
                  onTap: _pickOpeningTime,
                ),
                required: true,
              );
              final closing = _fieldBlock(
                'Closing Time',
                _timeField(
                  value: _closingTime,
                  placeholder: 'Select closing time',
                  onTap: _pickClosingTime,
                ),
                required: true,
              );
              final duration = _fieldBlock(
                'Recommended Sightseeing Time',
                _durationDropdown(),
                required: true,
              );

              if (compact) {
                return Column(
                  children: [
                    opening,
                    const SizedBox(height: 16),
                    closing,
                    const SizedBox(height: 16),
                    duration,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: opening),
                  const SizedBox(width: 16),
                  Expanded(child: closing),
                  const SizedBox(width: 16),
                  Expanded(child: duration),
                ],
              );
            },
          ),
        ],
      ),
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final adult = _priceItem(
                label: 'Adult',
                age: '13 - 59 years',
                controller: adultController,
              );
              final child = _priceItem(
                label: 'Child',
                age: '12 years and below',
                controller: childController,
              );
              final senior = _priceItem(
                label: 'Senior Citizen',
                age: '60 years and above',
                controller: seniorController,
              );

              if (compact) {
                return Column(
                  children: [
                    adult,
                    const SizedBox(height: 14),
                    child,
                    const SizedBox(height: 14),
                    senior,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: adult),
                  const SizedBox(width: 14),
                  Expanded(child: child),
                  const SizedBox(width: 14),
                  Expanded(child: senior),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _priceItem({
    required String label,
    required String age,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          age,
          style: const TextStyle(fontSize: 11, color: secondaryText),
        ),
        const SizedBox(height: 7),
        _moneyField(controller: controller, enabled: !_isFreeEntry),
      ],
    );
  }

  Widget _locationContact() {
    return _sectionCard(
      title: 'Location & Contact',
      subtitle:
      'Provide the attraction address, map coordinates and Malaysian phone number.',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _label(
            'Full Address',
            required: true,
          ),
          _textField(
            controller:
            _addressController,
            hint:
            'Enter the complete attraction address...',
            maxLines: 3,
            maxLength: 250,
          ),
          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Map Coordinates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    textColor,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                _controller
                    .isProcessing
                    ? null
                    : _openMapPicker,
                style:
                OutlinedButton
                    .styleFrom(
                  foregroundColor:
                  mainGreen,
                  side:
                  const BorderSide(
                    color:
                    mainGreen,
                  ),
                ),
                icon:
                const Icon(
                  Icons.map_outlined,
                  size: 18,
                ),
                label:
                const Text(
                  'Find on Map',
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 7,
          ),
          LayoutBuilder(
            builder:
                (context, constraints) {
              final compact =
                  constraints.maxWidth <
                      650;

              final latitude =
              _fieldBlock(
                'Latitude',
                _coordinateField(
                  controller:
                  _latitudeController,
                  hint:
                  'e.g. 5.415000',
                ),
                required: true,
              );

              final longitude =
              _fieldBlock(
                'Longitude',
                _coordinateField(
                  controller:
                  _longitudeController,
                  hint:
                  'e.g. 100.337100',
                ),
                required: true,
              );

              if (compact) {
                return Column(
                  children: [
                    latitude,
                    const SizedBox(
                      height: 14,
                    ),
                    longitude,
                  ],
                );
              }

              return Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: latitude,
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: longitude,
                  ),
                ],
              );
            },
          ),
          const SizedBox(
            height: 6,
          ),
          const Text(
            'You can enter the coordinates manually or click Find on Map to search and pin the attraction location.',
            style: TextStyle(
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          const SizedBox(
            height: 18,
          ),

          LayoutBuilder(
            builder:
                (context, constraints) {
              return SizedBox(
                width:
                constraints.maxWidth <
                    600
                    ? double.infinity
                    : 500,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    _label(
                      'Phone Number',
                      required: true,
                    ),
                    _phoneField(),
                    const SizedBox(
                      height: 5,
                    ),
                    const Text(
                      'Malaysia format only. Example: +60123456789',
                      style:
                      TextStyle(
                        fontSize: 11,
                        color:
                        secondaryText,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _coordinateField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      enabled:
      !_controller.isProcessing,
      keyboardType:
      const TextInputType
          .numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'[-0-9.]'),
        ),
        LengthLimitingTextInputFormatter(
          16,
        ),
      ],
      decoration:
      _inputDecoration(
        hint: hint,
      ),
    );
  }

  double? _parsedLatitude() {
    final value = double.tryParse(
      _latitudeController.text.trim(),
    );

    if (value == null ||
        value < -90 ||
        value > 90) {
      return null;
    }

    return value;
  }

  double? _parsedLongitude() {
    final value = double.tryParse(
      _longitudeController.text.trim(),
    );

    if (value == null ||
        value < -180 ||
        value > 180) {
      return null;
    }

    return value;
  }

  Future<void> _openMapPicker() async {
    final latitude =
    _parsedLatitude();
    final longitude =
    _parsedLongitude();

    final result =
    await Navigator.push<
        AttractionMapSelection>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AttractionMapPickerPage(
              initialLatitude:
              latitude,
              initialLongitude:
              longitude,
              initialSearchText:
              _addressController.text
                  .trim(),
            ),
      ),
    );

    if (!mounted ||
        result == null) {
      return;
    }

    setState(() {
      _latitudeController.text =
          result.latitude
              .toStringAsFixed(6);

      _longitudeController.text =
          result.longitude
              .toStringAsFixed(6);

      if (_addressController.text
          .trim()
          .isEmpty &&
          result.address != null &&
          result.address!
              .trim()
              .isNotEmpty) {
        _addressController.text =
            result.address!.trim();
      }
    });
  }

  Widget _facilitySection() {
    return _sectionCard(
      title: 'Facilities Provided',
      subtitle: 'Select all facilities available at this attraction.',
      icon: Icons.accessible_forward_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width < 560 ? width : (width < 900 ? (width - 14) / 2 : 245.0);

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _facilityOptions.map((facility) {
              final selected = _selectedFacilities.contains(facility);
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _controller.isProcessing
                    ? null
                    : () {
                  setState(() {
                    selected
                        ? _selectedFacilities.remove(facility)
                        : _selectedFacilities.add(facility);
                  });
                },
                child: Container(
                  width: itemWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? mainGreen.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? mainGreen : borderColor),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selected,
                        activeColor: mainGreen,
                        visualDensity: VisualDensity.compact,
                        onChanged: _controller.isProcessing
                            ? null
                            : (value) {
                          setState(() {
                            value == true
                                ? _selectedFacilities.add(facility)
                                : _selectedFacilities.remove(facility);
                          });
                        },
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          facility,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _highlightSection() {
    return _sectionCard(
      title: 'Highlights',
      subtitle: 'Add key experiences or special features of the attraction.',
      icon: Icons.star_outline,
      child: Column(
        children: [
          for (int i = 0; i < _highlightControllers.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _highlightControllers.length - 1 ? 0 : 12,
              ),
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
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _controller.isProcessing
                          ? null
                          : () => _removeHighlight(i),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _controller.isProcessing ? null : _addHighlight,
              icon: const Icon(Icons.add),
              label: const Text('Add Highlight'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mainGreen,
                side: const BorderSide(color: mainGreen),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageSection() {
    final newImages = _controller.selectedImages;

    return _sectionCard(
      title: 'Attraction Images',
      subtitle: 'Upload multiple images and choose one image as the cover.',
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_existingImageUrls.isNotEmpty) ...[
            const Text(
              'Existing Images',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _existingImageUrls.map(_existingImageCard).toList(),
            ),
            const SizedBox(height: 20),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _controller.isProcessing ? null : _controller.pickImages,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 38, color: mainGreen),
                  SizedBox(height: 10),
                  Text(
                    'Click to upload attraction images',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'JPG, JPEG, PNG or WEBP • Multiple images allowed',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: secondaryText),
                  ),
                ],
              ),
            ),
          ),
          if (newImages.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${newImages.length} new image${newImages.length == 1 ? '' : 's'} selected',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
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
          child: const Icon(Icons.broken_image_outlined, size: 34),
        ),
      ),
      onRemove: () {
        setState(() {
          _existingImageUrls.remove(url);
          if (_existingCoverUrl == url) {
            _existingCoverUrl =
            _existingImageUrls.isEmpty ? null : _existingImageUrls.first;
          }
        });
      },
      onSetCover: isCover
          ? null
          : () {
        setState(() => _existingCoverUrl = url);
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
      image: Image.memory(bytes, width: 215, height: 140, fit: BoxFit.cover),
      onRemove: () => _controller.removeImage(index),
      onSetCover: isCover
          ? null
          : () {
        setState(() => _existingCoverUrl = null);
        _controller.setCoverImage(index);
      },
    );
  }

  Widget _imageCardShell({
    required bool isCover,
    required Widget image,
    required VoidCallback onRemove,
    required VoidCallback? onSetCover,
  }) {
    return Container(
      width: 215,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isCover ? mainGreen : borderColor,
          width: isCover ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: image,
              ),
              Positioned(
                right: 7,
                top: 7,
                child: InkWell(
                  onTap: _controller.isProcessing ? null : onRemove,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18, color: Colors.red),
                  ),
                ),
              ),
              if (isCover)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: mainGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Cover',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _controller.isProcessing ? null : onSetCover,
              icon: Icon(
                isCover ? Icons.check_circle : Icons.image_outlined,
                size: 17,
              ),
              label: Text(isCover ? 'Cover Image' : 'Set as Cover'),
              style: TextButton.styleFrom(foregroundColor: mainGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSection() {
    return _sectionCard(
      title: 'Status',
      subtitle: 'Choose whether this attraction is visible and available.',
      icon: Icons.toggle_on_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final active = _statusOption(
            label: 'Active',
            description: 'Attraction is available to users.',
            value: 'Active',
          );
          final inactive = _statusOption(
            label: 'Inactive',
            description: 'Attraction is temporarily hidden.',
            value: 'Inactive',
          );

          if (compact) {
            return Column(
              children: [active, const SizedBox(height: 12), inactive],
            );
          }

          return Row(
            children: [
              Expanded(child: active),
              const SizedBox(width: 16),
              Expanded(child: inactive),
            ],
          );
        },
      ),
    );
  }

  Widget _statusOption({
    required String label,
    required String description,
    required String value,
  }) {
    final selected = _status == value;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _controller.isProcessing
          ? null
          : () => setState(() => _status = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? mainGreen.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? mainGreen : borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _status,
              activeColor: mainGreen,
              onChanged: _controller.isProcessing
                  ? null
                  : (newValue) {
                if (newValue != null) setState(() => _status = newValue);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 650;

        final cancel = SizedBox(
          width:
          compact ? double.infinity : 150,
          height: 52,
          child: OutlinedButton(
            onPressed:
            _controller.isProcessing
                ? null
                : () =>
                Navigator.pop(context),
            style:
            OutlinedButton.styleFrom(
              foregroundColor:
              const Color(0xFF344054),
              side: const BorderSide(
                color: Color(0xFFD0D5DD),
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(7),
              ),
            ),
            child:
            const Text('Cancel'),
          ),
        );

        final primaryButton =
        (!_isEdit &&
            _isCulturalHeritage)
            ? SizedBox(
          width: compact
              ? double.infinity
              : 170,
          height: 52,
          child:
          ElevatedButton.icon(
            onPressed:
            _controller
                .isProcessing
                ? null
                : () =>
                _saveAttraction(
                  openHeritageAfterSave:
                  true,
                ),
            style:
            ElevatedButton
                .styleFrom(
              backgroundColor:
              mainGreen,
              foregroundColor:
              Colors.white,
              elevation: 0,
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius
                    .circular(7),
              ),
            ),
            icon: _controller
                .isProcessing
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2.5,
                color:
                Colors.white,
              ),
            )
                : const Icon(
              Icons
                  .arrow_forward,
              size: 19,
            ),
            label: Text(
              _controller
                  .isProcessing
                  ? 'Saving...'
                  : 'Next',
            ),
          ),
        )
            : SizedBox(
          width: compact
              ? double.infinity
              : 180,
          height: 52,
          child:
          ElevatedButton(
            onPressed:
            _controller
                .isProcessing
                ? null
                : () =>
                _saveAttraction(),
            style:
            ElevatedButton
                .styleFrom(
              backgroundColor:
              mainGreen,
              foregroundColor:
              Colors.white,
              elevation: 0,
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius
                    .circular(7),
              ),
            ),
            child:
            _controller.isProcessing
                ? Row(
              mainAxisAlignment:
              MainAxisAlignment
                  .center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2.5,
                    color:
                    Colors.white,
                  ),
                ),
                const SizedBox(
                  width: 9,
                ),
                Text(
                  _isEdit
                      ? 'Saving...'
                      : 'Adding...',
                ),
              ],
            )
                : Row(
              mainAxisAlignment:
              MainAxisAlignment
                  .center,
              children: [
                Icon(
                  _isEdit
                      ? Icons
                      .save_outlined
                      : Icons.add,
                  size: 19,
                ),
                const SizedBox(
                  width: 7,
                ),
                Text(
                  _isEdit
                      ? 'Save Changes'
                      : 'Add Attraction',
                ),
              ],
            ),
          ),
        );

        if (compact) {
          return Column(
            children: [
              cancel,
              const SizedBox(height: 10),
              primaryButton,
            ],
          );
        }

        return Row(
          mainAxisAlignment:
          MainAxisAlignment.end,
          children: [
            cancel,
            const SizedBox(width: 12),
            primaryButton,
          ],
        );
      },
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: mainGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: mainGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _fieldBlock(String label, Widget field, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        field,
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (required)
            const Text(' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: !_controller.isProcessing,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: maxLength == null
          ? null
          : [LengthLimitingTextInputFormatter(maxLength)],
      decoration: _inputDecoration(hint: hint),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled && !_controller.isProcessing,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        LengthLimitingTextInputFormatter(7),
      ],
      decoration: InputDecoration(
        hintText: '0.00',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
        prefixIcon: Container(
          width: 54,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF2F4F7),
            border: Border(
              right: BorderSide(color: Color(0xFFD0D5DD)),
            ),
          ),
          child: const Text(
            'RM',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475467),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 54, minHeight: 50),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF2F4F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: mainGreen, width: 1.5),
        ),
      ),
    );
  }

  Widget _phoneField() {
    return TextField(
      controller: _phoneController,
      enabled: !_controller.isProcessing,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        hintText: '123456789',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
        prefixIcon: Container(
          width: 58,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF2F4F7),
            border: Border(
              right: BorderSide(color: Color(0xFFD0D5DD)),
            ),
          ),
          child: const Text(
            '+60',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475467),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 58, minHeight: 50),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: mainGreen, width: 1.5),
        ),
      ),
    );
  }

  Widget _categoryDropdown() {
    final items = <DropdownMenuItem<String>>[];
    final old = widget.attraction;
    final oldIncluded = old == null ||
        _controller.categories.any((category) => category.id == old.categoryId);

    if (old != null && !oldIncluded && old.categoryId.isNotEmpty) {
      items.add(
        DropdownMenuItem<String>(
          value: old.categoryId,
          child: Text(
            old.categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    items.addAll(
      _controller.categories.map(
            (CategoryModel category) => DropdownMenuItem<String>(
          value: category.id,
          child: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    final valueExists = _selectedCategoryId == null ||
        items.any((item) => item.value == _selectedCategoryId);

    return DropdownButtonFormField<String>(
      value: valueExists ? _selectedCategoryId : null,
      isExpanded: true,
      hint: const Text('Select category', overflow: TextOverflow.ellipsis),
      decoration: _dropdownDecoration(),
      items: items,
      onChanged: _controller.isProcessing
          ? null
          : (value) => setState(() => _selectedCategoryId = value),
    );
  }

  Widget _stateDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedState,
      isExpanded: true,
      hint: const Text('Select state', overflow: TextOverflow.ellipsis),
      decoration: _dropdownDecoration(),
      items: _states
          .map(
            (state) => DropdownMenuItem<String>(
          value: state,
          child: Text(state, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      )
          .toList(),
      onChanged: _controller.isProcessing
          ? null
          : (value) => setState(() => _selectedState = value),
    );
  }

  Widget _durationDropdown() {
    return DropdownButtonFormField<String>(
      value: _recommendedDuration,
      isExpanded: true,
      decoration: _dropdownDecoration(),
      items: _durationOptions
          .map(
            (duration) => DropdownMenuItem<String>(
          value: duration,
          child: Text(
            duration,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .toList(),
      onChanged: _controller.isProcessing
          ? null
          : (value) {
        if (value != null) setState(() => _recommendedDuration = value);
      },
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: mainGreen, width: 1.5),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: mainGreen, width: 1.5),
      ),
    );
  }

  Widget _timeField({
    required TimeOfDay? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: _controller.isProcessing ? null : onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFD0D5DD)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_outlined, size: 19, color: secondaryText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null ? placeholder : value.format(context),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: value == null ? const Color(0xFF98A2B3) : textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOpeningTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _openingTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (result != null && mounted) setState(() => _openingTime = result);
  }

  Future<void> _pickClosingTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _closingTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (result != null && mounted) setState(() => _closingTime = result);
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
    setState(() => _highlightControllers.add(TextEditingController()));
  }

  void _removeHighlight(int index) {
    if (_highlightControllers.length == 1) {
      _highlightControllers.first.clear();
      return;
    }
    final controller = _highlightControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  TimeOfDay? _parseTime(String value) {
    try {
      final parts = value.split(':');
      if (parts.length != 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  double? _validateFee(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    if (!RegExp(r'^\d{1,4}(\.\d{1,2})?$').hasMatch(text)) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0 || value > 9999) return null;
    return value;
  }

  Future<void> _saveAttraction({
    bool openHeritageAfterSave = false,
  }) async {
    final name = _nameController.text.trim();
    final area = _areaController.text.trim();
    final description = _descriptionController.text.trim();
    final address = _addressController.text.trim();
    final latitude = _parsedLatitude();
    final longitude = _parsedLongitude();
    final localPhone = _phoneController.text.trim();
    final fullPhone = '+60$localPhone';

    if (name.isEmpty ||
        _selectedCategoryId == null ||
        _selectedState == null ||
        area.isEmpty ||
        description.isEmpty ||
        address.isEmpty ||
        _latitudeController.text.trim().isEmpty ||
        _longitudeController.text.trim().isEmpty ||
        localPhone.isEmpty ||
        _openingTime == null ||
        _closingTime == null) {
      _showMessage('Please complete all required fields.', error: true);
      return;
    }

    if (name.length < 3) {
      _showMessage('Attraction name must contain at least 3 characters.', error: true);
      return;
    }

    if (area.length < 2) {
      _showMessage('Please enter a valid area.', error: true);
      return;
    }

    if (description.length < 20) {
      _showMessage('Description must contain at least 20 characters.', error: true);
      return;
    }

    if (address.length < 10) {
      _showMessage('Please enter a complete attraction address.', error: true);
      return;
    }

    if (latitude == null) {
      _showMessage(
        'Latitude must be a valid number between -90 and 90.',
        error: true,
      );
      return;
    }

    if (longitude == null) {
      _showMessage(
        'Longitude must be a valid number between -180 and 180.',
        error: true,
      );
      return;
    }

    if (!RegExp(r'^\+60\d{8,10}$').hasMatch(fullPhone)) {
      _showMessage(
        'Phone number must be a valid Malaysian number, e.g. +60123456789.',
        error: true,
      );
      return;
    }

    final openingMinutes = _openingTime!.hour * 60 + _openingTime!.minute;
    final closingMinutes = _closingTime!.hour * 60 + _closingTime!.minute;
    if (openingMinutes == closingMinutes) {
      _showMessage('Opening time and closing time cannot be the same.', error: true);
      return;
    }

    if (_existingImageUrls.isEmpty && _controller.selectedImages.isEmpty) {
      _showMessage('Please upload at least one attraction image.', error: true);
      return;
    }

    double malaysianAdultFee = 0;
    double malaysianChildFee = 0;
    double malaysianSeniorFee = 0;
    double nonMalaysianAdultFee = 0;
    double nonMalaysianChildFee = 0;
    double nonMalaysianSeniorFee = 0;

    if (!_isFreeEntry) {
      final values = [
        _validateFee(_malaysianAdultController),
        _validateFee(_malaysianChildController),
        _validateFee(_malaysianSeniorController),
        _validateFee(_nonMalaysianAdultController),
        _validateFee(_nonMalaysianChildController),
        _validateFee(_nonMalaysianSeniorController),
      ];

      if (values.any((value) => value == null)) {
        _showMessage(
          'Please enter all 6 entry fees using valid values from RM 0.00 to RM 9,999.00.',
          error: true,
        );
        return;
      }

      malaysianAdultFee = values[0]!;
      malaysianChildFee = values[1]!;
      malaysianSeniorFee = values[2]!;
      nonMalaysianAdultFee = values[3]!;
      nonMalaysianChildFee = values[4]!;
      nonMalaysianSeniorFee = values[5]!;
    }

    String? categoryName;
    for (final category in _controller.categories) {
      if (category.id == _selectedCategoryId) {
        categoryName = category.name;
        break;
      }
    }
    categoryName ??= widget.attraction?.categoryName;

    if (categoryName == null || categoryName.trim().isEmpty) {
      _showMessage('Please select a valid category.', error: true);
      return;
    }

    final highlights = _highlightControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    bool success;
    if (_isEdit) {
      final original = widget.attraction!;
      final removedUrls = original.imageUrls
          .where((url) => !_existingImageUrls.contains(url))
          .toList();

      success = await _controller.updateAttraction(
        original: original,
        name: name,
        categoryId: _selectedCategoryId!,
        categoryName: categoryName,
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
        openingTime: _formatTime(_openingTime!),
        closingTime: _formatTime(_closingTime!),
        recommendedDuration: _recommendedDuration,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phoneNumber: fullPhone,
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
        name: name,
        categoryId: _selectedCategoryId!,
        categoryName: categoryName,
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
        openingTime: _formatTime(_openingTime!),
        closingTime: _formatTime(_closingTime!),
        recommendedDuration: _recommendedDuration,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phoneNumber: fullPhone,
        facilities: _selectedFacilities.toList(),
        highlights: highlights,
        status: _status,
      );
    }

    if (!mounted) return;

    if (!success) {
      _showMessage(
        _isEdit
            ? 'Unable to update attraction. Check that the name is not duplicated and try again.'
            : 'Unable to add attraction. Check that the name is not duplicated and try again.',
        error: true,
      );
      return;
    }

    String? savedAttractionId;

    if (_isEdit) {
      savedAttractionId =
          widget.attraction!.id;
    } else {
      // The controller prevents duplicate attraction names,
      // so the exact name is safe to use to retrieve the
      // Firestore document created moments ago.
      final snapshot =
      await FirebaseFirestore.instance
          .collection('attractions')
          .where(
        'name',
        isEqualTo: name,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        savedAttractionId =
            snapshot.docs.first.id;
      }
    }

    if (!mounted) {
      return;
    }

    if (openHeritageAfterSave &&
        _isCulturalHeritage) {
      if (savedAttractionId == null ||
          savedAttractionId.isEmpty) {
        _showMessage(
          'Attraction was saved, but its document ID could not be found. '
              'Open Edit Attraction and try Add Cultural Information again.',
          error: true,
        );

        Navigator.pop(
          context,
          true,
        );
        return;
      }

      _showMessage(
        'Attraction added. Continue with cultural information.',
      );

      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminHeritageFormPage(
                attractionId:
                savedAttractionId!,
              ),
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
      return;
    }

    _showMessage(
      _isEdit
          ? 'Attraction updated successfully.'
          : 'Attraction added successfully.',
    );

    Navigator.pop(
      context,
      true,
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : mainGreen,
      ),
    );
  }
}
