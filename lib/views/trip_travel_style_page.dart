import 'package:flutter/material.dart';

import '../controllers/ai_trip_planner_controller.dart';
import 'generated_trip_page.dart';

class TripTravelStylePage extends StatefulWidget {
  final AiTripPlannerController controller;

  const TripTravelStylePage({
    super.key,
    required this.controller,
  });

  @override
  State<TripTravelStylePage> createState() =>
      _TripTravelStylePageState();
}

class _TripTravelStylePageState
    extends State<TripTravelStylePage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);

  // =========================================================
  // IMAGE FOR EACH TRAVEL STYLE
  // =========================================================

  final Map<String, String> images = const {
    'Sustainable Explorer':
    'assets/images/sustainable.png',

    'Culture Seeker':
    'assets/images/culture.png',

    'Nature Lover':
    'assets/images/nature.png',

    'Relax & Unwind':
    'assets/images/relax.png',

    'Adventure Enthusiast':
    'assets/images/adventure.png',

    'Foodie':
    'assets/images/foodie.png',
  };

  // =========================================================
  // DESCRIPTION
  // =========================================================

  final Map<String, String> desc = const {
    'Sustainable Explorer':
    'Eco-conscious travel, support local communities and protect nature.',

    'Culture Seeker':
    'Immerse in local culture, history, and authentic experiences.',

    'Nature Lover':
    'Immerse in local culture, history, and authentic experiences.',

    'Relax & Unwind':
    'Take it slow and enjoy relaxing sports, spas, and beautiful beaches.',

    'Adventure Enthusiast':
    'Thrill-seeking activities, hiking, trekking, and adrenaline adventures.',

    'Foodie':
    'Discover local cuisines, food markets, and unique dining experiences.',
  };

  // =========================================================
  // GENERATE TRIP
  // =========================================================

  Future<void> _generate() async {
    if (widget.controller.preferences.travelStyle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a travel style.',
          ),
        ),
      );

      return;
    }

    final ok =
    await widget.controller.generateTrip();

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ??
                'Unable to generate trip.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeneratedTripPage(
          controller: widget.controller,
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.controller.preferences.travelStyle;

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [

            // =================================================
            // APP BAR
            // =================================================

            _appBar(),

            // =================================================
            // CONTENT
            // =================================================

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  6,
                  14,
                  20,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    // =================================================
                    // HEADER
                    // =================================================

                    const Row(
                      children: [

                        CircleAvatar(
                          radius: 20,
                          backgroundColor: lightGreen,

                          child: Icon(
                            Icons.eco_rounded,
                            color: mainGreen,
                            size: 25,
                          ),
                        ),

                        SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,

                            children: [

                              Text(
                                'What’s your travel style?',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                  FontWeight.w700,
                                ),
                              ),

                              SizedBox(height: 2),

                              Text(
                                'Help our AI craft the perfect itinerary for you.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color:
                                  Color(0xFF777777),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // TITLE
                    // =================================================

                    const Text(
                      'Choose your travel style',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 2),

                    const Text(
                      'Select the style that best represents how you like to travel.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF777777),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =================================================
                    // TRAVEL STYLE GRID
                    // =================================================

                    GridView.builder(
                      shrinkWrap: true,

                      physics:
                      const NeverScrollableScrollPhysics(),

                      itemCount:
                      AiTripPlannerController
                          .travelStyles
                          .length,

                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(

                        // 3 cards in one row
                        crossAxisCount: 3,

                        crossAxisSpacing: 6,

                        mainAxisSpacing: 7,

                        // Smaller card
                        childAspectRatio: 1.15,
                      ),

                      itemBuilder:
                          (context, index) {

                        final style =
                        AiTripPlannerController
                            .travelStyles[index];

                        final isSelected =
                            selected == style;

                        return _travelStyleCard(
                          style: style,
                          isSelected: isSelected,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // BOTTOM BUTTON
            // =================================================

            Container(
              color: Colors.white,

              padding:
              const EdgeInsets.fromLTRB(
                14,
                8,
                14,
                10,
              ),

              child: SizedBox(
                width: double.infinity,
                height: 42,

                child: ElevatedButton(
                  onPressed:
                  widget.controller.isLoading
                      ? null
                      : _generate,

                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,

                    foregroundColor:
                    Colors.white,

                    elevation: 0,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        6,
                      ),
                    ),
                  ),

                  child:
                  widget.controller.isLoading

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

                      : const Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      Text(
                        'Next: Generate My Trip',
                        style:
                        TextStyle(
                          fontSize: 11,
                          fontWeight:
                          FontWeight
                              .w500,
                        ),
                      ),

                      SizedBox(width: 7),

                      Icon(
                        Icons
                            .arrow_forward_ios_rounded,
                        size: 11,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TRAVEL STYLE CARD
  // =========================================================

  Widget _travelStyleCard({
    required String style,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        widget.controller
            .setTravelStyle(style);

        setState(() {});
      },

      borderRadius:
      BorderRadius.circular(8),

      child: AnimatedContainer(
        duration:
        const Duration(
          milliseconds: 180,
        ),

        padding:
        const EdgeInsets.fromLTRB(
          5,
          6,
          5,
          6,
        ),

        decoration: BoxDecoration(
          color: isSelected
              ? lightGreen
              : Colors.white,

          border: Border.all(
            color: isSelected
                ? mainGreen
                : const Color(0xFFDADADA),

            width:
            isSelected ? 1.4 : 1,
          ),

          borderRadius:
          BorderRadius.circular(8),
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            // =================================================
            // IMAGE
            // =================================================

            Stack(
              children: [

                SizedBox(
                  width: double.infinity,
                  height: 58,

                  child: Center(
                    child: Image.asset(
                      images[style]!,
                      height: 55,
                      width: 72,
                      fit:
                      BoxFit.contain,

                      errorBuilder:
                          (
                          context,
                          error,
                          stackTrace,
                          ) {
                        return const Icon(
                          Icons.image_outlined,
                          size: 32,
                          color:
                          Color(0xFFAAAAAA),
                        );
                      },
                    ),
                  ),
                ),

                // Selected check icon
                if (isSelected)
                  const Positioned(
                    top: 0,
                    right: 0,

                    child: Icon(
                      Icons
                          .check_circle_rounded,

                      color: mainGreen,

                      size: 16,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 3),

            // =================================================
            // STYLE NAME
            // =================================================

            Text(
              style,

              maxLines: 1,

              overflow:
              TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 8.3,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 3),

            // =================================================
            // DESCRIPTION
            // =================================================

            Expanded(
              child: Text(
                desc[style] ?? '',

                maxLines: 5,

                overflow:
                TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 6.9,

                  height: 1.22,

                  color:
                  Color(0xFF777777),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // APP BAR
  // =========================================================

  Widget _appBar() {
    return SizedBox(
      height: 48,

      child: Row(
        children: [

          IconButton(
            onPressed: () =>
                Navigator.pop(context),

            icon: const Icon(
              Icons
                  .arrow_back_ios_new_rounded,

              size: 17,
            ),
          ),

          const Expanded(
            child: Text(
              'AI Trip Planner',

              textAlign:
              TextAlign.center,

              style: TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }
}