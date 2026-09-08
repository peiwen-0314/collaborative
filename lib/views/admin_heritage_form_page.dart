import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/admin_heritage_service.dart';
import 'admin_sidebar.dart';

class AdminHeritageFormPage extends StatefulWidget {
  const AdminHeritageFormPage({
    super.key,
    required this.attractionId,
  });

  final String attractionId;

  @override
  State<AdminHeritageFormPage> createState() =>
      _AdminHeritageFormPageState();
}

class _AdminHeritageFormPageState
    extends State<AdminHeritageFormPage> {
  static const Color mainGreen = Color(0xFF0B6B2B);
  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF667085);

  final AdminHeritageService _service =
  AdminHeritageService();

  final _formKey =
  GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingStamp = false;
  bool _existingHeritage = false;

  final ImagePicker _imagePicker = ImagePicker();

  String _attractionName = '';

  late final TextEditingController
  heritageType;
  late final TextEditingController yearBuilt;
  late final TextEditingController
  architecturalStyle;
  late final TextEditingController
  heritageStatus;
  late final TextEditingController history;
  late final TextEditingController
  culturalSignificance;
  late final TextEditingController bestTime;
  late final TextEditingController
  sustainabilityTip;
  late final TextEditingController
  visitorEtiquette;

  final List<TextEditingController>
  _aliasControllers = [
    TextEditingController(),
  ];

  final List<TextEditingController>
  _visitorEtiquetteControllers = [
    TextEditingController(),
  ];

  final List<TextEditingController>
  _conservationGuidelineControllers = [
    TextEditingController(),
  ];

  final List<TextEditingController>
  _dressCodeControllers = [
    TextEditingController(),
  ];

  final List<TextEditingController>
  _photographyRestrictionControllers = [
    TextEditingController(),
  ];

  final List<TextEditingController>
  _preservationPracticeControllers = [
    TextEditingController(),
  ];
  late final TextEditingController
  audioEnglish;
  late final TextEditingController audioMalay;
  late final TextEditingController
  audioChinese;
  late final TextEditingController
  stampImageUrl;

  @override
  void initState() {
    super.initState();

    heritageType =
        TextEditingController(
          text: 'Heritage Site',
        );
    yearBuilt =
        TextEditingController();
    architecturalStyle =
        TextEditingController();
    heritageStatus =
        TextEditingController();
    history =
        TextEditingController();
    culturalSignificance =
        TextEditingController();
    bestTime =
        TextEditingController();
    sustainabilityTip =
        TextEditingController();
    visitorEtiquette =
        TextEditingController();
    audioEnglish =
        TextEditingController();
    audioMalay =
        TextEditingController();
    audioChinese =
        TextEditingController();
    stampImageUrl =
        TextEditingController();

    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      heritageType,
      yearBuilt,
      architecturalStyle,
      heritageStatus,
      history,
      culturalSignificance,
      bestTime,
      sustainabilityTip,
      visitorEtiquette,
      audioEnglish,
      audioMalay,
      audioChinese,
      stampImageUrl,
    ]) {
      controller.dispose();
    }

    for (final controllers in [
      _aliasControllers,
      _visitorEtiquetteControllers,
      _conservationGuidelineControllers,
      _dressCodeControllers,
      _photographyRestrictionControllers,
      _preservationPracticeControllers,
    ]) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }

    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getMasterAttraction(
          widget.attractionId,
        ),
        _service
            .getHeritageInformationByAttractionId(
          widget.attractionId,
        ),
      ]);

      final master =
      results[0] as Map<String, dynamic>?;
      final heritage =
      results[1] as Map<String, dynamic>?;

      if (!mounted) {
        return;
      }

      _attractionName =
          master?['name']
              ?.toString()
              .trim() ??
              widget.attractionId;

      if (heritage != null) {
        _existingHeritage = true;

        heritageType.text =
            _text(
              heritage,
              'heritageType',
              fallback: 'Heritage Site',
            );
        _setListControllers(
          _aliasControllers,
          heritage['aliases'],
        );
        yearBuilt.text =
            _text(
              heritage,
              'yearBuilt',
            );
        architecturalStyle.text =
            _text(
              heritage,
              'architecturalStyle',
            );
        heritageStatus.text =
            _text(
              heritage,
              'heritageStatus',
            );
        history.text =
            _text(
              heritage,
              'history',
            );
        culturalSignificance.text =
            _text(
              heritage,
              'culturalSignificance',
            );
        bestTime.text =
            _text(
              heritage,
              'bestTime',
            );
        sustainabilityTip.text =
            _text(
              heritage,
              'sustainabilityTip',
            );
        visitorEtiquette.text =
            _text(
              heritage,
              'visitorEtiquette',
            );
        _setListControllers(
          _visitorEtiquetteControllers,
          heritage['visitorEtiquetteItems'],
        );
        _setListControllers(
          _conservationGuidelineControllers,
          heritage['conservationGuidelines'],
        );
        _setListControllers(
          _dressCodeControllers,
          heritage['dressCode'],
        );
        _setListControllers(
          _photographyRestrictionControllers,
          heritage['photographyRestrictions'],
        );
        _setListControllers(
          _preservationPracticeControllers,
          heritage['preservationPractices'],
        );
        audioEnglish.text =
            _text(
              heritage,
              'audioEnglish',
            );
        audioMalay.text =
            _text(
              heritage,
              'audioMalay',
            );
        audioChinese.text =
            _text(
              heritage,
              'audioChinese',
            );
        stampImageUrl.text =
            _text(
              heritage,
              'stampImageUrl',
            );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor:
          Colors.red.shade700,
          content: Text(
            'Unable to load cultural information: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _text(
      Map<String, dynamic> data,
      String key, {
        String fallback = '',
      }) {
    final value =
        data[key]
            ?.toString()
            .trim() ??
            '';

    return value.isEmpty
        ? fallback
        : value;
  }

  void _setListControllers(
      List<TextEditingController> controllers,
      dynamic value,
      ) {
    final items = value is List
        ? value
        .map(
          (item) =>
          item.toString().trim(),
    )
        .where(
          (item) => item.isNotEmpty,
    )
        .toList()
        : <String>[];

    for (final controller in controllers) {
      controller.dispose();
    }

    controllers
      ..clear()
      ..addAll(
        items.isEmpty
            ? [TextEditingController()]
            : items.map(
              (item) =>
              TextEditingController(
                text: item,
              ),
        ),
      );
  }

  List<String> _listValues(
      List<TextEditingController> controllers,
      ) {
    return controllers
        .map(
          (controller) =>
          controller.text.trim(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toList();
  }

  void _addListItem(
      List<TextEditingController> controllers,
      ) {
    setState(() {
      controllers.add(
        TextEditingController(),
      );
    });
  }

  void _removeListItem(
      List<TextEditingController> controllers,
      int index,
      ) {
    setState(() {
      if (controllers.length == 1) {
        controllers.first.clear();
        return;
      }

      final controller =
      controllers.removeAt(index);
      controller.dispose();
    });
  }

  Widget _dynamicListField({
    required String label,
    required List<TextEditingController> controllers,
    required String hint,
    required String addLabel,
    bool required = false,
    int maxLength = 180,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          const SizedBox(height: 7),
          for (int i = 0; i < controllers.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == controllers.length - 1 ? 0 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controllers[i],
                      enabled: !_saving && !_uploadingStamp,
                      maxLength: maxLength,
                      validator: (value) {
                        if (required &&
                            (value == null || value.trim().isEmpty)) {
                          return '$label is required.';
                        }
                        return null;
                      },
                      decoration: _inputDecoration(hint: hint),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: (_saving || _uploadingStamp)
                        ? null
                        : () => _removeListItem(controllers, i),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: (_saving || _uploadingStamp)
                  ? null
                  : () => _addListItem(controllers),
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateAudioLanguage(
      String? value,
      String language,
      ) {
    final text = value?.trim() ?? '';

// Required validation is handled by the TextFormField.
    if (text.isEmpty) {
      return null;
    }

    if (text.length < 20) {
      return 'Please enter at least 20 characters for the audio script.';
    }

    final chineseCharacters =
        RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]')
            .allMatches(text)
            .length;

    final latinCharacters =
        RegExp(r'[A-Za-zÀ-ÿ]')
            .allMatches(text)
            .length;

// ----------------------------------------------------------
// CHINESE
// ----------------------------------------------------------
    if (language == 'zh') {
      final totalLanguageCharacters =
          chineseCharacters + latinCharacters;

      if (chineseCharacters < 4) {
        return 'Chinese audio script should contain Chinese characters.';
      }

      if (totalLanguageCharacters > 0 &&
          chineseCharacters / totalLanguageCharacters < 0.50) {
        return 'This does not look like a Chinese audio script.';
      }

      return null;
    }

// English and Malay both use the Latin alphabet, so script
// detection alone cannot reliably distinguish them.
    if (chineseCharacters > 0) {
      return language == 'en'
          ? 'English audio script should not contain Chinese text.'
          : 'Malay audio script should not contain Chinese text.';
    }

    if (latinCharacters < 10) {
      return language == 'en'
          ? 'Please enter a valid English audio script.'
          : 'Please enter a valid Malay audio script.';
    }

    final words = RegExp(r"[A-Za-zÀ-ÿ']+")
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0) ?? '')
        .where((word) => word.isNotEmpty)
        .toList();

    const englishMarkers = <String>{
      'the',
      'is',
      'are',
      'and',
      'of',
      'to',
      'in',
      'for',
      'with',
      'this',
      'that',
      'was',
      'were',
      'has',
      'have',
      'visitors',
      'building',
      'site',
      'history',
      'cultural',
      'heritage',
    };

    const malayMarkers = <String>{
      'yang',
      'dan',
      'ini',
      'itu',
      'adalah',
      'untuk',
      'dengan',
      'pada',
      'dalam',
      'sebagai',
      'oleh',
      'para',
      'pelawat',
      'bangunan',
      'tapak',
      'sejarah',
      'budaya',
      'warisan',
    };

    final englishScore =
        words.where(englishMarkers.contains).length;

    final malayScore =
        words.where(malayMarkers.contains).length;

// Only reject when there is reasonably strong evidence that
// the script was entered in the wrong language. This avoids
// rejecting proper nouns or short tourism descriptions.
    if (language == 'en') {
      if (malayScore >= 2 &&
          malayScore > englishScore + 1) {
        return 'This appears to be Malay. Please enter the English audio script.';
      }
    } else if (language == 'ms') {
      if (englishScore >= 3 &&
          englishScore > malayScore + 1) {
        return 'This appears to be English. Please enter the Malay audio script.';
      }
    }

    return null;
  }


  String _stampContentType(String fileName) {
    final extension =
    fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickAndUploadStampImage() async {
    if (_saving || _uploadingStamp) {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1600,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _uploadingStamp = true;
    });

    try {
      final bytes = await picked.readAsBytes();

      final reference = FirebaseStorage.instance
          .ref()
          .child('heritage_stamps')
          .child(widget.attractionId)
          .child('stamp_image');

      await reference.putData(
        bytes,
        SettableMetadata(
          contentType: _stampContentType(picked.name),
          customMetadata: {
            'attractionId': widget.attractionId,
            'originalFileName': picked.name,
          },
        ),
      );

      final downloadUrl =
      await reference.getDownloadURL();

      if (!mounted) {
        return;
      }

      setState(() {
        stampImageUrl.text = downloadUrl;
      });

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: mainGreen,
          content: Text(
            'Stamp image uploaded successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Unable to upload stamp image: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingStamp = false;
        });
      }
    }
  }

  Widget _stampImageUploadField() {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
      ),
      child: FormField<String>(
        initialValue: stampImageUrl.text,
        builder: (field) {
          final imageUrl =
          stampImageUrl.text.trim();

          return Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Stamp Image',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 7),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD0D5DD),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFFF3F4F6),
                        borderRadius:
                        BorderRadius.circular(8),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: imageUrl.isEmpty
                          ? const Center(
                        child: Icon(
                          Icons
                              .image_outlined,
                          color:
                          Colors.black38,
                          size: 36,
                        ),
                      )
                          : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (
                            context,
                            error,
                            stackTrace,
                            ) {
                          return const Center(
                            child: Icon(
                              Icons
                                  .broken_image_outlined,
                              color:
                              Colors.black38,
                              size: 34,
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            imageUrl.isEmpty
                                ? 'No stamp image uploaded yet.'
                                : 'Stamp image uploaded.',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                              color: imageUrl.isEmpty
                                  ? Colors.black54
                                  : mainGreen,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'Optional. Upload a stamp image from your device. The image will be stored in Firebase Storage and its download URL will be saved automatically.',
                            style: TextStyle(
                              color:
                              Colors.black54,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 12),

                          ElevatedButton.icon(
                            onPressed:
                            _saving ||
                                _uploadingStamp
                                ? null
                                : () async {
                              await _pickAndUploadStampImage();

                              if (!mounted) {
                                return;
                              }

                              field.didChange(
                                stampImageUrl
                                    .text
                                    .trim(),
                              );
                            },
                            style:
                            ElevatedButton.styleFrom(
                              backgroundColor:
                              mainGreen,
                              foregroundColor:
                              Colors.white,
                            ),
                            icon: _uploadingStamp
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                Colors.white,
                              ),
                            )
                                : const Icon(
                              Icons
                                  .upload_file_outlined,
                            ),
                            label: Text(
                              _uploadingStamp
                                  ? 'Uploading...'
                                  : imageUrl.isEmpty
                                  ? 'Upload Stamp Image'
                                  : 'Replace Stamp Image',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic> _buildData() {
    final visitorItems =
    _listValues(
      _visitorEtiquetteControllers,
    );

    return {
      'heritageType':
      heritageType.text.trim(),
      'aliases':
      _listValues(
        _aliasControllers,
      ),
      'yearBuilt':
      yearBuilt.text.trim(),
      'architecturalStyle':
      architecturalStyle.text.trim(),
      'heritageStatus':
      heritageStatus.text.trim(),
      'history':
      history.text.trim(),
      'culturalSignificance':
      culturalSignificance.text.trim(),
      'bestTime':
      bestTime.text.trim(),
      'sustainabilityTip':
      sustainabilityTip.text.trim(),
      'visitorEtiquette':
      visitorEtiquette.text
          .trim()
          .isNotEmpty
          ? visitorEtiquette.text.trim()
          : visitorItems.join(' '),
      'visitorEtiquetteItems':
      visitorItems,
      'conservationGuidelines':
      _listValues(
        _conservationGuidelineControllers,
      ),
      'dressCode':
      _listValues(
        _dressCodeControllers,
      ),
      'photographyRestrictions':
      _listValues(
        _photographyRestrictionControllers,
      ),
      'preservationPractices':
      _listValues(
        _preservationPracticeControllers,
      ),
      'audioEnglish':
      audioEnglish.text.trim(),
      'audioMalay':
      audioMalay.text.trim(),
      'audioChinese':
      audioChinese.text.trim(),
      'stampImageUrl':
      stampImageUrl.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_uploadingStamp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait for the stamp image upload to finish.',
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _service
          .saveHeritageInformation(
        attractionId:
        widget.attractionId,
        data: _buildData(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor:
          mainGreen,
          content: Text(
            _existingHeritage
                ? 'Cultural information updated successfully.'
                : 'Cultural information added successfully.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor:
          Colors.red.shade700,
          content: Text(
            'Unable to save cultural information: $error',
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
            onCategoryTap: () {},
            onCulturalHeritageTap: () {
              // Cultural & Heritage information is managed inside
              // Attraction Management in the unified admin flow.
            },
            onStampTap: () {},
            onReportTap: () {},
            onLogoutTap: () {
              Navigator.popUntil(
                context,
                    (route) => route.isFirst,
              );
            },
          ),
          Expanded(
            child: Stack(
              children: [
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: mainGreen,
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _pageHeader(),
                              const SizedBox(height: 22),
                              _linkedAttractionCard(),
                              const SizedBox(height: 20),
                              _identitySection(),
                              const SizedBox(height: 20),
                              _historySection(),
                              const SizedBox(height: 20),
                              _visitorSection(),
                              const SizedBox(height: 20),
                              _audioSection(),
                              const SizedBox(height: 24),
                              _actions(),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_saving || _uploadingStamp)
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
          onPressed: (_saving || _uploadingStamp)
              ? null
              : () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _existingHeritage
                    ? 'Edit Cultural Information'
                    : 'Add Cultural Information',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _existingHeritage
                    ? 'Update the cultural and heritage information for $_attractionName.'
                    : 'Step 2 of 2: Complete the cultural and heritage information for $_attractionName.',
                style: const TextStyle(
                  fontSize: 13,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linkedAttractionCard() {
    return Container(
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
            Icons.link,
            color: mainGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Linked Attraction',
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _attractionName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identitySection() {
    return _section(
      title:
      'Heritage Identity',
      subtitle:
      'Enter the cultural and historical identity of this attraction.',
      icon:
      Icons.account_balance_outlined,
      children: [
        _dropdownField(
          label: 'Heritage Type',
          controller: heritageType,
          required: true,
          hint: 'Select heritage type',
          options: const [
            'Heritage Site',
            'Historical Building',
            'Religious Site',
            'Monument',
            'Museum',
            'Archaeological Site',
            'Cultural District',
            'Traditional Village',
            'Clan House',
            'Fort / Palace',
            'Cultural Landmark',
            'Other',
          ],
        ),
        _dynamicListField(
          label: 'Aliases',
          controllers: _aliasControllers,
          hint: 'e.g. Alternative historical name',
          addLabel: 'Add Alias',
          required: true,
        ),
        _twoColumns(
          _field(
            'Year Built',
            yearBuilt,
            required: true,
            hint: 'e.g. 1897',
          ),
          _field(
            'Architectural Style',
            architecturalStyle,
            required: true,
            hint: 'e.g. Moorish Revival',
          ),
        ),
        _field(
          'Heritage Status',
          heritageStatus,
          required: true,
          hint: 'e.g. National Heritage Landmark',
        ),
      ],
    );
  }

  Widget _historySection() {
    return _section(
      title:
      'Historical Information',
      subtitle:
      'Provide the story and cultural significance for visitors.',
      icon:
      Icons.history_edu_outlined,
      children: [
        _field(
          'History',
          history,
          maxLines: 7,
          required: true,
          hint:
          'Describe the history of the attraction...',
        ),
        _field(
          'Cultural Significance',
          culturalSignificance,
          maxLines: 5,
          required: true,
          hint:
          'Explain why this place is culturally significant...',
        ),
        _twoColumns(
          _dropdownField(
            label: 'Best Time',
            controller: bestTime,
            required: true,
            hint: 'Select best visiting time',
            options: const [
              'Any Time',
              'Early Morning',
              'Morning',
              'Late Morning',
              'Afternoon',
              'Late Afternoon',
              'Evening',
              'Night',
              'Morning / Evening',
            ],
          ),
          _field(
            'Sustainability Tip',
            sustainabilityTip,
            required: true,
            hint: 'Visitor sustainability advice',
          ),
        ),
        _stampImageUploadField(),
      ],
    );
  }

  Widget _visitorSection() {
    return _section(
      title:
      'Visitor Guidance',
      subtitle:
      'Add etiquette, restrictions and conservation guidance.',
      icon:
      Icons.rule_outlined,
      children: [
        _field(
          'Visitor Etiquette Summary',
          visitorEtiquette,
          maxLines: 4,
          required: true,
        ),
        _dynamicListField(
          label: 'Visitor Etiquette Items',
          controllers: _visitorEtiquetteControllers,
          hint: 'e.g. Keep voices low inside sacred areas',
          addLabel: 'Add Etiquette Item',
          required: true,
        ),
        _dynamicListField(
          label: 'Conservation Guidelines',
          controllers: _conservationGuidelineControllers,
          hint: 'e.g. Do not touch fragile historical surfaces',
          addLabel: 'Add Guideline',
          required: true,
        ),
        _dynamicListField(
          label: 'Dress Code',
          controllers: _dressCodeControllers,
          hint: 'e.g. Shoulders and knees should be covered',
          addLabel: 'Add Dress Code',
          required: true,
        ),
        _dynamicListField(
          label: 'Photography Restrictions',
          controllers: _photographyRestrictionControllers,
          hint: 'e.g. No flash photography inside the prayer hall',
          addLabel: 'Add Restriction',
          required: true,
        ),
        _dynamicListField(
          label: 'Preservation Practices',
          controllers: _preservationPracticeControllers,
          hint: 'e.g. Original timber is periodically conserved',
          addLabel: 'Add Preservation Practice',
          required: true,
        ),
      ],
    );
  }

  Widget _audioSection() {
    return _section(
      title:
      'Audio Guide Content',
      subtitle:
      'Enter the required narration text used by the heritage audio guide.',
      icon:
      Icons.headphones_outlined,
      children: [
        _field(
          'English Audio Script',
          audioEnglish,
          maxLines: 7,
          required: true,
          hint: 'Enter the narration in English.',
          validator: (value) =>
              _validateAudioLanguage(
                value,
                'en',
              ),
        ),
        _field(
          'Malay Audio Script',
          audioMalay,
          maxLines: 7,
          required: true,
          hint: 'Masukkan skrip narasi dalam Bahasa Melayu.',
          validator: (value) =>
              _validateAudioLanguage(
                value,
                'ms',
              ),
        ),
        _field(
          'Chinese Audio Script',
          audioChinese,
          maxLines: 7,
          required: true,
          hint: '请输入中文语音导览内容。',
          validator: (value) =>
              _validateAudioLanguage(
                value,
                'zh',
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
          ...children,
        ],
      ),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    bool required = false,
    String? hint,
  }) {
    final currentValue = controller.text.trim();
    final effectiveOptions = <String>[...options];

    if (currentValue.isNotEmpty &&
        !effectiveOptions.contains(currentValue)) {
      effectiveOptions.insert(0, currentValue);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            value: currentValue.isEmpty ? null : currentValue,
            isExpanded: true,
            hint: hint == null
                ? null
                : Text(
              hint,
              style: const TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 12,
              ),
            ),
            decoration: _inputDecoration(hint: ''),
            items: effectiveOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
                .toList(),
            onChanged: (_saving || _uploadingStamp)
                ? null
                : (value) {
              setState(() {
                controller.text = value ?? '';
              });
            },
            validator: (value) {
              if (required &&
                  (value == null || value.trim().isEmpty)) {
                return '$label is required.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _field(
      String label,
      TextEditingController controller, {
        bool required = false,
        int maxLines = 1,
        String? hint,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            enabled: !_saving && !_uploadingStamp,
            maxLines: maxLines,
            decoration: _inputDecoration(hint: hint ?? ''),
            validator: (value) {
              if (required &&
                  (value == null || value.trim().isEmpty)) {
                return '$label is required.';
              }

              if (validator != null) {
                return validator(value);
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _twoColumns(
      Widget first,
      Widget second,
      ) {
    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        if (constraints.maxWidth <
            700) {
          return Column(
            children: [
              first,
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Expanded(
              child: first,
            ),
            const SizedBox(
              width: 18,
            ),
            Expanded(
              child: second,
            ),
          ],
        );
      },
    );
  }

  Widget _actions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 550;

        final cancel = SizedBox(
          width: compact ? double.infinity : 130,
          height: 50,
          child: OutlinedButton(
            onPressed: (_saving || _uploadingStamp)
                ? null
                : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        );

        final save = SizedBox(
          width: compact ? double.infinity : 190,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_saving || _uploadingStamp) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: mainGreen,
              foregroundColor: Colors.white,
            ),
            icon: _saving
                ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.save),
            label: Text(
              _saving
                  ? 'Saving...'
                  : (_existingHeritage
                  ? 'Save Changes'
                  : 'Save Cultural Information'),
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
}
