import 'package:flutter/material.dart';

import '../controllers/attraction_import_controller.dart';
import '../services/geoapify_attraction_service.dart';

class BulkAttractionImportPage
    extends StatefulWidget {
  const BulkAttractionImportPage({
    super.key,
  });

  @override
  State<BulkAttractionImportPage>
  createState() =>
      _BulkAttractionImportPageState();
}

class _BulkAttractionImportPageState
    extends State<
        BulkAttractionImportPage> {
  static const Color mainGreen =
  Color(0xFF0B6B2B);

  static const Color pageBackground =
  Color(0xFFF7F8FA);

  static const Color borderColor =
  Color(0xFFE5E7EB);

  static const Color textColor =
  Color(0xFF111827);

  static const Color secondaryText =
  Color(0xFF667085);

  final AttractionImportController
  _controller =
  AttractionImportController();

  String _selectedState =
      'Kuala Lumpur';

  static const List<String>
  malaysiaStates = [
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

    _controller.addListener(
      _refreshPage,
    );
  }

  void _refreshPage() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(
      _refreshPage,
    );

    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      pageBackground,

      appBar: AppBar(
        backgroundColor:
        Colors.white,

        surfaceTintColor:
        Colors.white,

        elevation: 0,

        title: const Text(
          'Import Attractions',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
            FontWeight.w700,
            color: textColor,
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.all(
                  24,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    _introCard(),

                    const SizedBox(
                      height: 18,
                    ),

                    _searchCard(),

                    if (_controller
                        .errorMessage !=
                        null) ...[
                      const SizedBox(
                        height: 12,
                      ),

                      _messageBox(
                        _controller
                            .errorMessage!,
                        isError: true,
                      ),
                    ],

                    if (_controller
                        .successMessage !=
                        null) ...[
                      const SizedBox(
                        height: 12,
                      ),

                      _messageBox(
                        _controller
                            .successMessage!,
                      ),
                    ],

                    const SizedBox(
                      height: 20,
                    ),

                    if (_controller
                        .results
                        .isNotEmpty) ...[
                      _resultHeader(),

                      const SizedBox(
                        height: 10,
                      ),

                      ..._controller
                          .results
                          .map(
                        _attractionCard,
                      ),
                    ],

                    const SizedBox(
                      height: 90,
                    ),
                  ],
                ),
              ),
            ),

            if (_controller
                .results
                .isNotEmpty)
              _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        16,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFEAF6EE,
        ),

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border:
        Border.all(
          color:
          const Color(
            0xFFCDE8D5,
          ),
        ),
      ),

      child:
      const Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            'Search Attractions by State',
            style: TextStyle(
              fontSize: 15,
              fontWeight:
              FontWeight.w700,
              color: mainGreen,
            ),
          ),

          SizedBox(
            height: 5,
          ),

          Text(
            'Select one Malaysian state. The system searches multiple major tourism areas within that state, removes duplicates and places higher-quality attractions first.',
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color:
              secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        18,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border:
        Border.all(
          color:
          borderColor,
        ),
      ),

      child:
      LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final compact =
              constraints
                  .maxWidth <
                  650;

          final stateField =
          DropdownButtonFormField<
              String>(
            value:
            _selectedState,

            isExpanded:
            true,

            decoration:
            _inputDecoration(
              'State / Federal Territory',
            ),

            items:
            malaysiaStates
                .map(
                  (state) {
                return DropdownMenuItem<
                    String>(
                  value:
                  state,

                  child:
                  Text(
                    state,
                  ),
                );
              },
            ).toList(),

            onChanged:
            _controller
                .isSearching
                ? null
                : (value) {
              if (value ==
                  null) {
                return;
              }

              setState(
                    () {
                  _selectedState =
                      value;
                },
              );
            },
          );

          final searchButton =
          SizedBox(
            height:
            52,

            child:
            ElevatedButton(
              onPressed:
              _controller
                  .isSearching
                  ? null
                  : () {
                _controller
                    .searchByState(
                  state:
                  _selectedState,
                );
              },

              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                mainGreen,

                foregroundColor:
                Colors.white,

                elevation:
                0,

                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal:
                  24,
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
              _controller
                  .isSearching
                  ? const SizedBox(
                width:
                20,
                height:
                20,
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                  color:
                  Colors.white,
                ),
              )
                  : const Text(
                'Find Attractions',
                style:
                TextStyle(
                  fontSize:
                  13,
                  fontWeight:
                  FontWeight
                      .w600,
                ),
              ),
            ),
          );

          if (compact) {
            return Column(
              children: [
                stateField,

                const SizedBox(
                  height:
                  12,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  searchButton,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .end,

            children: [
              Expanded(
                child:
                stateField,
              ),

              const SizedBox(
                width:
                12,
              ),

              searchButton,
            ],
          );
        },
      ),
    );
  }

  Widget _resultHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,

            children: [
              Text(
                '${_controller.results.length} Attractions Found',
                style:
                const TextStyle(
                  fontSize:
                  15,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(
                height:
                2,
              ),

              const Text(
                'Higher-quality attractions are listed first.',
                style:
                TextStyle(
                  fontSize:
                  9,
                  color:
                  secondaryText,
                ),
              ),
            ],
          ),
        ),

        TextButton(
          onPressed:
          _controller
              .selectedCount ==
              _controller
                  .results
                  .length
              ? _controller
              .clearSelection
              : _controller
              .selectAll,

          child: Text(
            _controller
                .selectedCount ==
                _controller
                    .results
                    .length
                ? 'Clear All'
                : 'Select All',

            style:
            const TextStyle(
              color:
              mainGreen,
              fontSize:
              11,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _attractionCard(
      GeoapifyAttractionCandidate
      item,
      ) {
    final bool selected =
    _controller
        .isSelected(
      item,
    );

    return Container(
      margin:
      const EdgeInsets.only(
        bottom:
        10,
      ),

      padding:
      const EdgeInsets.all(
        12,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          9,
        ),

        border:
        Border.all(
          color:
          selected
              ? mainGreen
              : borderColor,

          width:
          selected
              ? 1.5
              : 1,
        ),
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Checkbox(
            value:
            selected,

            activeColor:
            mainGreen,

            onChanged:
            _controller
                .isImporting
                ? null
                : (_) {
              _controller
                  .toggleSelected(
                item,
              );
            },
          ),

          const SizedBox(
            width:
            4,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,

              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                      Text(
                        item.name,

                        maxLines:
                        1,

                        overflow:
                        TextOverflow
                            .ellipsis,

                        style:
                        const TextStyle(
                          fontSize:
                          12,

                          fontWeight:
                          FontWeight
                              .w700,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                      8,
                    ),

                    Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal:
                        7,
                        vertical:
                        3,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFFF2F4F7,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          20,
                        ),
                      ),

                      child:
                      Text(
                        'Score ${item.qualityScore}',

                        style:
                        const TextStyle(
                          fontSize:
                          7,
                          color:
                          secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  5,
                ),

                Text(
                  _locationText(
                    item,
                  ),

                  style:
                  const TextStyle(
                    fontSize:
                    9,
                    color:
                    secondaryText,
                  ),
                ),

                if (item.address
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                    4,
                  ),

                  Text(
                    item.address,

                    maxLines:
                    2,

                    overflow:
                    TextOverflow
                        .ellipsis,

                    style:
                    const TextStyle(
                      fontSize:
                      8,
                      height:
                      1.25,
                      color:
                      secondaryText,
                    ),
                  ),
                ],

                const SizedBox(
                  height:
                  7,
                ),

                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal:
                    8,
                    vertical:
                    4,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFE8F5E9,
                    ),

                    borderRadius:
                    BorderRadius
                        .circular(
                      20,
                    ),
                  ),

                  child:
                  Text(
                    item.categoryName,

                    style:
                    const TextStyle(
                      fontSize:
                      8,
                      color:
                      mainGreen,
                      fontWeight:
                      FontWeight
                          .w600,
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

  Widget _bottomBar() {
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        14,
      ),

      decoration:
      const BoxDecoration(
        color:
        Colors.white,

        border:
        Border(
          top:
          BorderSide(
            color:
            borderColor,
          ),
        ),
      ),

      child:
      LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final compact =
              constraints
                  .maxWidth <
                  600;

          final status =
          DropdownButtonFormField<
              String>(
            value:
            _controller
                .importStatus,

            isExpanded:
            true,

            decoration:
            _inputDecoration(
              'Import Status',
            ),

            items:
            const [
              DropdownMenuItem(
                value:
                'Draft',
                child:
                Text(
                  'Draft',
                ),
              ),

              DropdownMenuItem(
                value:
                'Active',
                child:
                Text(
                  'Active',
                ),
              ),
            ],

            onChanged:
            _controller
                .isImporting
                ? null
                : (value) {
              if (value ==
                  null) {
                return;
              }

              _controller
                  .setImportStatus(
                value,
              );
            },
          );

          final importButton =
          SizedBox(
            height:
            50,

            child:
            ElevatedButton(
              onPressed:
              _controller
                  .isImporting ||
                  _controller
                      .selectedCount ==
                      0
                  ? null
                  : () async {
                final result =
                await _controller
                    .importSelected();

                if (!mounted) {
                  return;
                }

                if (result.imported >
                    0) {
                  ScaffoldMessenger
                      .of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content:
                      Text(
                        '${result.imported} attraction(s) imported successfully.',
                      ),
                    ),
                  );
                }
              },

              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                mainGreen,

                foregroundColor:
                Colors.white,

                elevation:
                0,

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
              _controller
                  .isImporting
                  ? const SizedBox(
                width:
                19,
                height:
                19,
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                  color:
                  Colors.white,
                ),
              )
                  : Text(
                'Import (${_controller.selectedCount})',
                style:
                const TextStyle(
                  fontSize:
                  12,
                  fontWeight:
                  FontWeight
                      .w600,
                ),
              ),
            ),
          );

          if (compact) {
            return Column(
              children: [
                status,

                const SizedBox(
                  height:
                  10,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  importButton,
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width:
                230,
                child:
                status,
              ),

              const Spacer(),

              SizedBox(
                width:
                220,
                child:
                importButton,
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label,
      ) {
    return InputDecoration(
      labelText:
      label,

      labelStyle:
      const TextStyle(
        fontSize:
        11,
      ),

      filled:
      true,

      fillColor:
      Colors.white,

      contentPadding:
      const EdgeInsets.symmetric(
        horizontal:
        12,
        vertical:
        14,
      ),

      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          7,
        ),

        borderSide:
        const BorderSide(
          color:
          Color(
            0xFFD0D5DD,
          ),
        ),
      ),

      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          7,
        ),

        borderSide:
        const BorderSide(
          color:
          mainGreen,
        ),
      ),
    );
  }

  Widget _messageBox(
      String text, {
        bool isError = false,
      }) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        11,
      ),

      decoration:
      BoxDecoration(
        color:
        isError
            ? const Color(
          0xFFFFEEEE,
        )
            : const Color(
          0xFFE8F5E9,
        ),

        borderRadius:
        BorderRadius.circular(
          7,
        ),
      ),

      child:
      Text(
        text,

        style:
        TextStyle(
          fontSize:
          9,

          color:
          isError
              ? Colors
              .red
              .shade700
              : mainGreen,
        ),
      ),
    );
  }

  String _locationText(
      GeoapifyAttractionCandidate item,
      ) {
    if (item.area.isEmpty) {
      return item.state;
    }

    return '${item.area}, ${item.state}';
  }
}
