import 'package:flutter/material.dart';

import '../services/admin_heritage_service.dart';

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
  static const Color mainGreen =
  Color(0xFF2E7D32);
  static const Color background =
  Color(0xFFF5F7F5);
  static const Color borderColor =
  Color(0xFFE5E7EB);

  final AdminHeritageService _service =
  AdminHeritageService();

  final _formKey =
  GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _existingHeritage = false;

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
    required List<TextEditingController>
    controllers,
    required String hint,
    required String addLabel,
    int maxLength = 180,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
            const TextStyle(
              fontWeight:
              FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          for (
          int i = 0;
          i < controllers.length;
          i++
          )
            Padding(
              padding:
              EdgeInsets.only(
                bottom:
                i ==
                    controllers.length -
                        1
                    ? 0
                    : 12,
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                    TextFormField(
                      controller:
                      controllers[i],
                      maxLength:
                      maxLength,
                      decoration:
                      InputDecoration(
                        hintText:
                        hint,
                        counterText: '',
                        filled: true,
                        fillColor:
                        Colors.white,
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            8,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            borderColor,
                          ),
                        ),
                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            8,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            borderColor,
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            8,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            mainGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child:
                    OutlinedButton(
                      onPressed:
                      _saving
                          ? null
                          : () =>
                          _removeListItem(
                            controllers,
                            i,
                          ),
                      style:
                      OutlinedButton
                          .styleFrom(
                        padding:
                        EdgeInsets.zero,
                        foregroundColor:
                        Colors.red,
                        side:
                        const BorderSide(
                          color:
                          Color(
                            0xFFFECACA,
                          ),
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            7,
                          ),
                        ),
                      ),
                      child:
                      const Icon(
                        Icons
                            .delete_outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(
            height: 14,
          ),
          Align(
            alignment:
            Alignment.centerLeft,
            child:
            OutlinedButton.icon(
              onPressed:
              _saving
                  ? null
                  : () =>
                  _addListItem(
                    controllers,
                  ),
              icon:
              const Icon(
                Icons.add,
              ),
              label:
              Text(addLabel),
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
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
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

    // Audio scripts are optional.
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
    if (!_formKey.currentState!
        .validate()) {
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
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor:
        Colors.white,
        surfaceTintColor:
        Colors.white,
        title: Text(
          _existingHeritage
              ? 'Step 2 of 2: Edit Cultural Information'
              : 'Step 2 of 2: Add Cultural Information',
        ),
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(
          color: mainGreen,
        ),
      )
          : Form(
        key: _formKey,
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(
            28,
          ),
          child: Center(
            child:
            ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 1100,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  _linkedAttractionCard(),
                  const SizedBox(
                    height: 20,
                  ),
                  _identitySection(),
                  const SizedBox(
                    height: 20,
                  ),
                  _historySection(),
                  const SizedBox(
                    height: 20,
                  ),
                  _visitorSection(),
                  const SizedBox(
                    height: 20,
                  ),
                  _audioSection(),
                  const SizedBox(
                    height: 24,
                  ),
                  _actions(),
                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkedAttractionCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
        const Color(0xFFEAF5E9),
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(
          color:
          mainGreen.withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.link,
            color: mainGreen,
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _attractionName,
                  style:
                  const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'Linked Attraction ID: ${widget.attractionId}',
                  style:
                  const TextStyle(
                    color:
                    Colors.black54,
                    fontSize: 12,
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
          controllers:
          _aliasControllers,
          hint:
          'e.g. Alternative historical name',
          addLabel:
          'Add Alias',
        ),
        _twoColumns(
          _field(
            'Year Built',
            yearBuilt,
            hint: 'e.g. 1897',
          ),
          _field(
            'Architectural Style',
            architecturalStyle,
            hint:
            'e.g. Moorish Revival',
          ),
        ),
        _field(
          'Heritage Status',
          heritageStatus,
          hint:
          'e.g. National Heritage Landmark',
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
            hint:
            'Visitor sustainability advice',
          ),
        ),
        _field(
          'Stamp Image URL',
          stampImageUrl,
          hint:
          'Optional Firebase Storage stamp image URL',
        ),
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
        ),
        _dynamicListField(
          label:
          'Visitor Etiquette Items',
          controllers:
          _visitorEtiquetteControllers,
          hint:
          'e.g. Keep voices low inside sacred areas',
          addLabel:
          'Add Etiquette Item',
        ),
        _dynamicListField(
          label:
          'Conservation Guidelines',
          controllers:
          _conservationGuidelineControllers,
          hint:
          'e.g. Do not touch fragile historical surfaces',
          addLabel:
          'Add Guideline',
        ),
        _dynamicListField(
          label: 'Dress Code',
          controllers:
          _dressCodeControllers,
          hint:
          'e.g. Shoulders and knees should be covered',
          addLabel:
          'Add Dress Code',
        ),
        _dynamicListField(
          label:
          'Photography Restrictions',
          controllers:
          _photographyRestrictionControllers,
          hint:
          'e.g. No flash photography inside the prayer hall',
          addLabel:
          'Add Restriction',
        ),
        _dynamicListField(
          label:
          'Preservation Practices',
          controllers:
          _preservationPracticeControllers,
          hint:
          'e.g. Original timber is periodically conserved',
          addLabel:
          'Add Preservation Practice',
        ),
      ],
    );
  }

  Widget _audioSection() {
    return _section(
      title:
      'Audio Guide Content',
      subtitle:
      'Optional narration text used by the heritage audio guide.',
      icon:
      Icons.headphones_outlined,
      children: [
        _field(
          'English Audio Script',
          audioEnglish,
          maxLines: 7,
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
      padding:
      const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
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
                decoration:
                BoxDecoration(
                  color: mainGreen
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius
                      .circular(10),
                ),
                child: Icon(
                  icon,
                  color: mainGreen,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      title,
                      style:
                      const TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      subtitle,
                      style:
                      const TextStyle(
                        fontSize: 12,
                        color:
                        Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 22,
          ),
          ...children,
        ],
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
    final currentValue =
    controller.text.trim();

    final effectiveOptions =
    <String>[
      ...options,
    ];

    if (currentValue.isNotEmpty &&
        !effectiveOptions.contains(
          currentValue,
        )) {
      effectiveOptions.insert(
        0,
        currentValue,
      );
    }

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style:
                    TextStyle(
                      color:
                      Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          DropdownButtonFormField<
              String>(
            value:
            currentValue.isEmpty
                ? null
                : currentValue,
            isExpanded: true,
            hint:
            hint == null
                ? null
                : Text(hint),
            decoration:
            InputDecoration(
              filled: true,
              fillColor:
              Colors.white,
              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius
                    .circular(
                  8,
                ),
                borderSide:
                const BorderSide(
                  color:
                  borderColor,
                ),
              ),
              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius
                    .circular(
                  8,
                ),
                borderSide:
                const BorderSide(
                  color:
                  borderColor,
                ),
              ),
              focusedBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius
                    .circular(
                  8,
                ),
                borderSide:
                const BorderSide(
                  color:
                  mainGreen,
                  width:
                  1.5,
                ),
              ),
            ),
            items:
            effectiveOptions
                .map(
                  (option) =>
                  DropdownMenuItem<
                      String>(
                    value:
                    option,
                    child:
                    Text(
                      option,
                      overflow:
                      TextOverflow
                          .ellipsis,
                    ),
                  ),
            )
                .toList(),
            onChanged:
            _saving
                ? null
                : (value) {
              setState(
                    () {
                  controller.text =
                      value ??
                          '';
                },
              );
            },
            validator:
                (value) {
              if (required &&
                  (value == null ||
                      value
                          .trim()
                          .isEmpty)) {
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
      padding:
      const EdgeInsets.only(
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration:
            InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius
                    .circular(8),
                borderSide:
                const BorderSide(
                  color: borderColor,
                ),
              ),
              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius
                    .circular(8),
                borderSide:
                const BorderSide(
                  color: borderColor,
                ),
              ),
              focusedBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius
                    .circular(8),
                borderSide:
                const BorderSide(
                  color: mainGreen,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (required &&
                  (value == null ||
                      value.trim().isEmpty)) {
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
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _saving
              ? null
              : () {
            Navigator.pop(
              context,
              false,
            );
          },
          child:
          const Text('Cancel'),
        ),
        const SizedBox(
          width: 12,
        ),
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
              strokeWidth: 2,
              color:
              Colors.white,
            ),
          )
              : const Icon(
            Icons.save_outlined,
          ),
          label: Text(
            _saving
                ? 'Saving...'
                : _existingHeritage
                ? 'Save Cultural Information'
                : 'Add Cultural Information',
          ),
        ),
      ],
    );
  }
}
