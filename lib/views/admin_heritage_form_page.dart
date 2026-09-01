import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/admin_heritage_service.dart';

class AdminCulturalHeritageFormPage
    extends StatefulWidget {
  const AdminCulturalHeritageFormPage({
    super.key,
    this.record,
  });

  final AdminHeritageRecord? record;

  bool get isEditing => record != null;

  @override
  State<AdminCulturalHeritageFormPage>
  createState() =>
      _AdminCulturalHeritageFormPageState();
}

class _AdminCulturalHeritageFormPageState
    extends State<AdminCulturalHeritageFormPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFF5F7F5);

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final AdminHeritageService _service =
  AdminHeritageService();

  final ImagePicker _picker = ImagePicker();

  bool _saving = false;
  bool _choosingImage = false;
  String _status = 'Active';

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  late final TextEditingController name;
  late final TextEditingController aliases;
  late final TextEditingController state;
  late final TextEditingController city;
  late final TextEditingController category;
  late final TextEditingController latitude;
  late final TextEditingController longitude;
  late final TextEditingController openingHours;
  late final TextEditingController shortDescription;
  late final TextEditingController recommendedTime;
  late final TextEditingController bestTime;
  late final TextEditingController sustainabilityTip;

  late final TextEditingController yearBuilt;
  late final TextEditingController architecturalStyle;
  late final TextEditingController heritageStatus;
  late final TextEditingController history;
  late final TextEditingController culturalSignificance;

  late final TextEditingController conservationGuidelines;
  late final TextEditingController visitorEtiquetteItems;
  late final TextEditingController dressCode;
  late final TextEditingController photographyRestrictions;
  late final TextEditingController preservationPractices;

  late final TextEditingController audioEnglish;
  late final TextEditingController audioMalay;
  late final TextEditingController audioChinese;

  @override
  void initState() {
    super.initState();

    final heritage = widget.record?.attraction;

    _status = widget.record?.status ?? 'Active';

    name = TextEditingController(
      text: heritage?.name ?? '',
    );

    aliases = TextEditingController(
      text: heritage?.aliases.join('\n') ?? '',
    );

    state = TextEditingController(
      text: heritage?.state ?? '',
    );

    city = TextEditingController(
      text: heritage?.city ?? '',
    );

    category = TextEditingController(
      text: heritage?.category ?? 'Heritage Site',
    );

    latitude = TextEditingController(
      text: heritage == null
          ? ''
          : heritage.latitude.toString(),
    );

    longitude = TextEditingController(
      text: heritage == null
          ? ''
          : heritage.longitude.toString(),
    );

    openingHours = TextEditingController(
      text: heritage?.openingHours ?? '',
    );

    shortDescription = TextEditingController(
      text: heritage?.shortDescription ?? '',
    );

    recommendedTime = TextEditingController(
      text: heritage?.recommendedTime ?? '',
    );

    bestTime = TextEditingController(
      text: heritage?.bestTime ?? '',
    );

    sustainabilityTip = TextEditingController(
      text: heritage?.sustainabilityTip ?? '',
    );

    yearBuilt = TextEditingController(
      text: heritage?.yearBuilt ?? '',
    );

    architecturalStyle = TextEditingController(
      text: heritage?.architecturalStyle ?? '',
    );

    heritageStatus = TextEditingController(
      text: heritage?.heritageStatus ?? '',
    );

    history = TextEditingController(
      text: heritage?.history ?? '',
    );

    culturalSignificance = TextEditingController(
      text: heritage?.culturalSignificance ?? '',
    );

    conservationGuidelines =
        TextEditingController(
          text: heritage?.conservationGuidelines
              .join('\n') ??
              '',
        );

    visitorEtiquetteItems =
        TextEditingController(
          text: heritage?.visitorEtiquetteItems
              .join('\n') ??
              '',
        );

    dressCode = TextEditingController(
      text: heritage?.dressCode.join('\n') ?? '',
    );

    photographyRestrictions =
        TextEditingController(
          text: heritage?.photographyRestrictions
              .join('\n') ??
              '',
        );

    preservationPractices =
        TextEditingController(
          text: heritage?.preservationPractices
              .join('\n') ??
              '',
        );

    audioEnglish = TextEditingController(
      text: heritage?.audioEnglish ?? '',
    );

    audioMalay = TextEditingController(
      text: heritage?.audioMalay ?? '',
    );

    audioChinese = TextEditingController(
      text: heritage?.audioChinese ?? '',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      aliases,
      state,
      city,
      category,
      latitude,
      longitude,
      openingHours,
      shortDescription,
      recommendedTime,
      bestTime,
      sustainabilityTip,
      yearBuilt,
      architecturalStyle,
      heritageStatus,
      history,
      culturalSignificance,
      conservationGuidelines,
      visitorEtiquetteItems,
      dressCode,
      photographyRestrictions,
      preservationPractices,
      audioEnglish,
      audioMalay,
      audioChinese,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _choosingImage = true;
    });

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } finally {
      if (mounted) {
        setState(() {
          _choosingImage = false;
        });
      }
    }
  }

  List<String> _lines(
      TextEditingController controller,
      ) {
    return controller.text
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    return null;
  }

  String? _coordinateValidator(
      String? value,
      ) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    if (double.tryParse(value.trim()) == null) {
      return 'Enter a valid number';
    }

    return null;
  }

  Map<String, dynamic> _buildData() {
    final visitorItems =
    _lines(visitorEtiquetteItems);

    return {
      'name': name.text.trim(),
      'aliases': _lines(aliases),
      'state': state.text.trim(),
      'city': city.text.trim(),
      'category': category.text.trim(),
      'latitude':
      double.parse(latitude.text.trim()),
      'longitude':
      double.parse(longitude.text.trim()),
      'openingHours':
      openingHours.text.trim(),
      'shortDescription':
      shortDescription.text.trim(),
      'recommendedTime':
      recommendedTime.text.trim(),
      'bestTime': bestTime.text.trim(),
      'sustainabilityTip':
      sustainabilityTip.text.trim(),

      'yearBuilt': yearBuilt.text.trim(),
      'architecturalStyle':
      architecturalStyle.text.trim(),
      'heritageStatus':
      heritageStatus.text.trim(),
      'history': history.text.trim(),
      'culturalSignificance':
      culturalSignificance.text.trim(),

      'conservationGuidelines':
      _lines(conservationGuidelines),
      'visitorEtiquetteItems':
      visitorItems,

      // Keep compatibility with the older string field too.
      'visitorEtiquette':
      visitorItems.join(' '),

      'dressCode':
      _lines(dressCode),
      'photographyRestrictions':
      _lines(photographyRestrictions),
      'preservationPractices':
      _lines(preservationPractices),

      'audioEnglish':
      audioEnglish.text.trim(),
      'audioMalay':
      audioMalay.text.trim(),
      'audioChinese':
      audioChinese.text.trim(),

      'status': _status,
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // New heritage places must have an uploaded image.
    if (!widget.isEditing &&
        _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload a heritage image.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final data = _buildData();

      if (widget.isEditing) {
        await _service.updateHeritagePlace(
          id: widget.record!.attraction.id,
          data: data,
          newImage: _selectedImage,
        );
      } else {
        await _service.addHeritagePlace(
          data: data,
          image: _selectedImage!,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Cultural & heritage information updated successfully.'
                : 'Heritage place added successfully.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Save failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.isEditing
              ? 'Edit Cultural & Heritage Information'
              : 'Add Heritage Place',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 1050,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // =====================================================
                  // IMAGE UPLOAD
                  // =====================================================
                  _section(
                    title: 'Heritage Image',
                    subtitle:
                    'Upload an image. The Firebase Storage URL is generated automatically.',
                    icon: Icons.image_outlined,
                    children: [
                      _imageUpload(),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // BASIC INFORMATION
                  // =====================================================
                  _section(
                    title: 'Basic Information',
                    subtitle:
                    'Basic information for this cultural or heritage place.',
                    icon:
                    Icons.info_outline_rounded,
                    children: [
                      _twoColumns(
                        _field(
                          controller: name,
                          label:
                          'Heritage Place Name',
                          validator: _required,
                        ),
                        _field(
                          controller: category,
                          label: 'Category',
                          validator: _required,
                        ),
                      ),

                      _twoColumns(
                        _field(
                          controller: city,
                          label: 'City',
                          validator: _required,
                        ),
                        _field(
                          controller: state,
                          label: 'State',
                          validator: _required,
                        ),
                      ),

                      _twoColumns(
                        _field(
                          controller: latitude,
                          label: 'Latitude',
                          validator:
                          _coordinateValidator,
                        ),
                        _field(
                          controller: longitude,
                          label: 'Longitude',
                          validator:
                          _coordinateValidator,
                        ),
                      ),

                      _twoColumns(
                        _field(
                          controller: openingHours,
                          label:
                          'Opening Hours',
                        ),
                        _field(
                          controller: recommendedTime,
                          label:
                          'Estimated Visit Time',
                        ),
                      ),

                      _twoColumns(
                        _field(
                          controller: bestTime,
                          label:
                          'Best Time to Visit',
                        ),
                        _statusField(),
                      ),

                      _field(
                        controller: aliases,
                        label:
                        'Recognition Aliases',
                        hint:
                        'One alias per line',
                        maxLines: 4,
                      ),

                      _field(
                        controller:
                        shortDescription,
                        label:
                        'Short Description',
                        maxLines: 4,
                      ),

                      _field(
                        controller:
                        sustainabilityTip,
                        label:
                        'Sustainability Tip',
                        maxLines: 3,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // HISTORICAL INFORMATION
                  // =====================================================
                  _section(
                    title:
                    'Historical Information',
                    subtitle:
                    'Information displayed on the Historical Information page.',
                    icon:
                    Icons.menu_book_outlined,
                    children: [
                      _twoColumns(
                        _field(
                          controller: yearBuilt,
                          label: 'Year Built',
                        ),
                        _field(
                          controller:
                          architecturalStyle,
                          label:
                          'Architectural Style',
                        ),
                      ),

                      _field(
                        controller:
                        heritageStatus,
                        label:
                        'Heritage Status',
                      ),

                      _field(
                        controller: history,
                        label:
                        'Historical Background',
                        maxLines: 10,
                      ),

                      _field(
                        controller:
                        culturalSignificance,
                        label:
                        'Cultural Significance',
                        maxLines: 7,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // VISITOR & CONSERVATION
                  // =====================================================
                  _section(
                    title:
                    'Visitor & Conservation Information',
                    subtitle:
                    'Enter one item per line for each section.',
                    icon: Icons.eco_outlined,
                    children: [
                      _field(
                        controller:
                        conservationGuidelines,
                        label:
                        'Conservation Guidelines',
                        hint:
                        'One guideline per line',
                        maxLines: 6,
                      ),

                      _field(
                        controller:
                        visitorEtiquetteItems,
                        label:
                        'Visitor Etiquette',
                        hint:
                        'One item per line',
                        maxLines: 6,
                      ),

                      _field(
                        controller: dressCode,
                        label: 'Dress Code',
                        hint:
                        'One item per line',
                        maxLines: 5,
                      ),

                      _field(
                        controller:
                        photographyRestrictions,
                        label:
                        'Photography Restrictions',
                        hint:
                        'One item per line',
                        maxLines: 6,
                      ),

                      _field(
                        controller:
                        preservationPractices,
                        label:
                        'Preservation Practices',
                        hint:
                        'One item per line',
                        maxLines: 6,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // AUDIO CONTENT
                  // =====================================================
                  _section(
                    title:
                    'Multilingual Audio Guide Content',
                    subtitle:
                    'Text scripts used by the existing TTS/audio guide.',
                    icon:
                    Icons.headphones_outlined,
                    children: [
                      _field(
                        controller:
                        audioEnglish,
                        label:
                        'English Audio Content',
                        maxLines: 8,
                      ),

                      _field(
                        controller: audioMalay,
                        label:
                        'Bahasa Melayu Audio Content',
                        maxLines: 8,
                      ),

                      _field(
                        controller:
                        audioChinese,
                        label:
                        '中文 Audio Content',
                        maxLines: 8,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () {
                          Navigator.pop(
                            context,
                          );
                        },
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor:
                          mainGreen,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          side:
                          const BorderSide(
                            color: mainGreen,
                          ),
                        ),
                        child:
                        const Text('Cancel'),
                      ),

                      const SizedBox(width: 12),

                      FilledButton.icon(
                        onPressed:
                        _saving ? null : _save,
                        style:
                        FilledButton.styleFrom(
                          backgroundColor:
                          mainGreen,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            color:
                            Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(
                          Icons.save_outlined,
                        ),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : widget.isEditing
                              ? 'Save Changes'
                              : 'Add Heritage Place',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageUpload() {
    final existingImage =
        widget.record?.attraction.imageUrl ?? '';

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 220,
          height: 145,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F5),
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color:
              mainGreen.withOpacity(0.18),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _selectedImageBytes != null
              ? Image.memory(
            _selectedImageBytes!,
            fit: BoxFit.cover,
          )
              : existingImage.isNotEmpty
              ? Image.network(
            existingImage,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) {
              return const _ImagePlaceholder();
            },
          )
              : const _ImagePlaceholder(),
        ),

        const SizedBox(width: 18),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload heritage image',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.isEditing
                    ? 'Choose a new image only if you want to replace the current image.'
                    : 'Choose an image from your computer. The image will be uploaded to Firebase Storage when you save.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              OutlinedButton.icon(
                onPressed:
                _choosingImage
                    ? null
                    : _pickImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: mainGreen,
                  side: const BorderSide(
                    color: mainGreen,
                  ),
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: _choosingImage
                    ? const SizedBox(
                  width: 17,
                  height: 17,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: mainGreen,
                  ),
                )
                    : const Icon(
                  Icons.upload_file_outlined,
                ),
                label: Text(
                  _selectedImage == null
                      ? 'Choose Image'
                      : 'Change Image',
                ),
              ),

              if (_selectedImage != null) ...[
                const SizedBox(height: 9),
                Text(
                  _selectedImage!.name,
                  style: const TextStyle(
                    color: mainGreen,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFE8F5E9),
                  borderRadius:
                  BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: mainGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color:
                        Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          ...children,
        ],
      ),
    );
  }

  Widget _twoColumns(
      Widget left,
      Widget right,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              left,
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: _decoration(
          label: label,
          hint: hint,
        ),
      ),
    );
  }

  Widget _statusField() {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _status,
        decoration: _decoration(
          label: 'Status',
        ),
        items: const [
          DropdownMenuItem(
            value: 'Active',
            child: Text('Active'),
          ),
          DropdownMenuItem(
            value: 'Draft',
            child: Text('Draft'),
          ),
          DropdownMenuItem(
            value: 'Inactive',
            child: Text('Inactive'),
          ),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }

          setState(() {
            _status = value;
          });
        },
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: const Color(0xFFF9FAF9),

      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: BorderSide(
          color:
          mainGreen.withOpacity(0.18),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: mainGreen,
          width: 1.4,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide:
        const BorderSide(
          color: Colors.red,
        ),
      ),

      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide:
        const BorderSide(
          color: Colors.red,
          width: 1.4,
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 38,
            color: Color(0xFF2E7D32),
          ),
          SizedBox(height: 6),
          Text(
            'No image selected',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
