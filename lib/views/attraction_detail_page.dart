import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/attraction.dart';
import '../services/attraction_reviews_service.dart';
import '../services/saved_attractions_service.dart';
import 'attraction_reviews_page.dart';
import 'write_attraction_review_page.dart';


class AttractionDetailPage extends StatelessWidget {
  final AttractionModel attraction;

  final double? estimatedFee;

  const AttractionDetailPage({
    super.key,
    required this.attraction,
    this.estimatedFee,
  });

  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color secondaryText = Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    final String hero =
    attraction.coverImageUrl.trim().isNotEmpty
        ? attraction.coverImageUrl
        : attraction.imageUrls.isNotEmpty
        ? attraction.imageUrls.first
        : '';

    final String second =
    attraction.imageUrls.length > 1
        ? attraction.imageUrls[1]
        : hero;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =====================================================
              // HERO IMAGE
              // =====================================================
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 210,
                    child: hero.isEmpty
                        ? Container(
                      color: lightGreen,
                      child: const Icon(
                        Icons.landscape_outlined,
                        size: 70,
                        color: mainGreen,
                      ),
                    )
                        : Image.network(
                      hero,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: lightGreen,
                          child: const Icon(
                            Icons.landscape_outlined,
                            size: 70,
                            color: mainGreen,
                          ),
                        );
                      },
                    ),
                  ),

                  Positioned(
                    left: 10,
                    top: 10,
                    child: CircleAvatar(
                      backgroundColor:
                      Colors.white.withValues(alpha: 0.9),
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 17,
                        ),
                      ),
                    ),
                  ),

                  // =====================================================
                  // SAVE / UNSAVE
                  // =====================================================
                  Positioned(
                    right: 10,
                    top: 10,
                    child: StreamBuilder<Set<String>>(
                      stream: SavedAttractionsService
                          .instance
                          .watchSavedIds(),
                      builder: (context, snapshot) {
                        final isSaved =
                            snapshot.data?.contains(
                              attraction.id,
                            ) ??
                                false;

                        return CircleAvatar(
                          backgroundColor:
                          Colors.white.withValues(
                            alpha: 0.92,
                          ),
                          child: IconButton(
                            tooltip: isSaved
                                ? 'Remove from saved'
                                : 'Save attraction',
                            onPressed: () async {
                              try {
                                final nowSaved =
                                await SavedAttractionsService
                                    .instance
                                    .toggle(
                                  attraction,
                                );

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                )
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      backgroundColor:
                                      mainGreen,
                                      content: Text(
                                        nowSaved
                                            ? '${attraction.name} saved.'
                                            : '${attraction.name} removed from saved.',
                                      ),
                                    ),
                                  );
                              } catch (_) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please login before saving attractions.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              isSaved
                                  ? Icons.favorite_rounded
                                  : Icons
                                  .favorite_border_rounded,
                              color: mainGreen,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // =====================================================
              // MAIN CARD
              // =====================================================
              Transform.translate(
                offset: const Offset(0, -70),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2E2E2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =================================================
                      // NAME
                      // =================================================
                      Text(
                        attraction.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // =================================================
                      // CATEGORY + LOCATION
                      // =================================================
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (attraction.categoryName.trim().isNotEmpty)
                            _pill(
                              attraction.categoryName,
                            ),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: mainGreen,
                                size: 13,
                              ),

                              const SizedBox(width: 3),

                              Text(
                                _locationText(),
                                style: const TextStyle(
                                  color: mainGreen,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // =================================================
                      // RATING / REVIEWS - CLICKABLE
                      // =================================================
                      AnimatedBuilder(
                        animation:
                        AttractionReviewsService.instance,
                        builder: (context, _) {
                          final service =
                              AttractionReviewsService.instance;

                          final rating =
                          service.averageRatingFor(
                            attraction.id,
                          );

                          final count =
                          service.reviewCountFor(
                            attraction.id,
                          );

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AttractionReviewsPage(
                                        attraction:
                                        attraction,
                                      ),
                                ),
                              );
                            },
                            borderRadius:
                            BorderRadius.circular(8),
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 5,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    rating > 0
                                        ? Icons.star_rounded
                                        : Icons
                                        .star_border_rounded,
                                    size: 17,
                                    color: const Color(
                                      0xFFFFB300,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 4,
                                  ),

                                  Text(
                                    rating > 0
                                        ? rating
                                        .toStringAsFixed(
                                      1,
                                    )
                                        : 'Not rated yet',
                                    style:
                                    const TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                      FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 5,
                                  ),

                                  Text(
                                    '($count review${count == 1 ? '' : 's'})',
                                    style:
                                    const TextStyle(
                                      fontSize: 8,
                                      color:
                                      secondaryText,
                                    ),
                                  ),

                                  const Spacer(),

                                  const Text(
                                    'View Reviews',
                                    style:
                                    TextStyle(
                                      fontSize: 8,
                                      color:
                                      mainGreen,
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 2,
                                  ),

                                  const Icon(
                                    Icons
                                        .chevron_right_rounded,
                                    size: 17,
                                    color:
                                    mainGreen,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      const Divider(),

                      const SizedBox(height: 8),

                      // =================================================
                      // QUICK INFORMATION
                      // =================================================
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // =================================================
                          // ENTRY FEE - CLICKABLE
                          // =================================================
                          Expanded(
                            child: InkWell(
                              onTap: attraction.isFreeEntry
                                  ? null
                                  : () {
                                _showAdmissionRates(
                                  context,
                                );
                              },
                              borderRadius:
                              BorderRadius.circular(8),
                              child: _info(
                                Icons.payments_outlined,
                                estimatedFee != null
                                    ? 'Estimated Fee'
                                    : 'Entry Fee',
                                _entryFeeText(),
                              ),
                            ),
                          ),

                          // =================================================
                          // OPENING HOURS
                          // =================================================
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _showWeeklyOpeningHours(context);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: _info(
                                Icons.schedule_outlined,
                                'Opening Hours',
                                _todayOpeningHours(),
                                helperText: 'Tap to view week',
                              ),
                            ),
                          ),

                          // =================================================
                          // DURATION
                          // =================================================
                          Expanded(
                            child: _info(
                              Icons.hourglass_bottom_rounded,
                              'Visit Duration',
                              attraction.recommendedDuration
                                  .trim()
                                  .isEmpty
                                  ? '-'
                                  : attraction
                                  .recommendedDuration,
                            ),
                          ),

                          // =================================================
                          // CONTACT
                          // =================================================
                          Expanded(
                            child: _info(
                              Icons.phone_outlined,
                              'Contact',
                              attraction.phoneNumber
                                  .trim()
                                  .isEmpty
                                  ? '-'
                                  : attraction.phoneNumber,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // =================================================
                      // ABOUT
                      // =================================================
                      const Text(
                        'About This Attraction',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              attraction.description
                                  .trim()
                                  .isEmpty
                                  ? 'No description available.'
                                  : attraction.description,
                              style: const TextStyle(
                                fontSize: 10,
                                color: secondaryText,
                                height: 1.4,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          ClipRRect(
                            borderRadius:
                            BorderRadius.circular(8),
                            child: SizedBox(
                              width: 112,
                              height: 78,
                              child: second.isEmpty
                                  ? Container(
                                color: lightGreen,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: mainGreen,
                                ),
                              )
                                  : Image.network(
                                second,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) {
                                  return Container(
                                    color: lightGreen,
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: mainGreen,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // =================================================
                      // HIGHLIGHTS + FACILITIES
                      // =================================================
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _list(
                              'Highlights',
                              Icons.eco_outlined,
                              attraction.highlights,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: _facilities(
                              attraction.facilities,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Divider(),

                      const SizedBox(height: 12),

                      // =================================================
                      // REVIEWS
                      // =================================================
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Reviews',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AttractionReviewsPage(
                                        attraction:
                                        attraction,
                                      ),
                                ),
                              );
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 8,
                                color: mainGreen,
                              ),
                            ),
                          ),
                        ],
                      ),

                      AnimatedBuilder(
                        animation:
                        AttractionReviewsService.instance,
                        builder: (context, _) {
                          final service =
                              AttractionReviewsService.instance;

                          final rating =
                          service.averageRatingFor(
                            attraction.id,
                          );

                          final count =
                          service.reviewCountFor(
                            attraction.id,
                          );

                          return Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.all(
                              11,
                            ),
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius:
                              BorderRadius.circular(
                                9,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons
                                      .rate_review_outlined,
                                  size: 20,
                                  color:
                                  mainGreen,
                                ),

                                const SizedBox(
                                  width: 9,
                                ),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        rating > 0
                                            ? '${rating.toStringAsFixed(1)} / 5'
                                            : 'No ratings yet',
                                        style:
                                        const TextStyle(
                                          fontSize: 10,
                                          fontWeight:
                                          FontWeight
                                              .w700,
                                          color:
                                          mainGreen,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 2,
                                      ),
                                      Text(
                                        count == 0
                                            ? 'Be the first to share your experience.'
                                            : 'Based on $count review${count == 1 ? '' : 's'}',
                                        style:
                                        const TextStyle(
                                          fontSize: 7.5,
                                          color:
                                          secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child:
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    WriteAttractionReviewPage(
                                      attraction:
                                      attraction,
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons
                                .edit_outlined,
                            size: 15,
                          ),
                          label: const Text(
                            'Write a Review',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                          style:
                          OutlinedButton.styleFrom(
                            foregroundColor:
                            mainGreen,
                            side: const BorderSide(
                              color: mainGreen,
                            ),
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                8,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Divider(),

                      const SizedBox(height: 12),

                      // =================================================
                      // LOCATION
                      // =================================================
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        _locationText(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        attraction.address.trim().isEmpty
                            ? 'Address not provided'
                            : attraction.address,
                        style: const TextStyle(
                          fontSize: 9,
                          color: secondaryText,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // =================================================
                      // GET DIRECTIONS
                      // =================================================
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _openGoogleMaps(context);
                          },
                          icon: const Icon(
                            Icons.navigation_outlined,
                            size: 17,
                          ),
                          label: const Text(
                            'Get Directions',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: mainGreen,
                            side: const BorderSide(
                              color: mainGreen,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ENTRY FEE TEXT
  // ============================================================

  String _entryFeeText() {
    if (attraction.isFreeEntry) {
      return 'Free';
    }

    // ==========================================================
    // GENERATED TRIP
    // ==========================================================
    if (estimatedFee != null) {
      return 'MYR ${_formatMoney(estimatedFee!)}';
    }

    // ==========================================================
    // HOME / RECOMMENDED
    // ==========================================================
    if (attraction.malaysianAdultFee > 0) {
      return 'From MYR ${_formatMoney(
        attraction.malaysianAdultFee,
      )}';
    }

    if (attraction.nonMalaysianAdultFee > 0) {
      return 'From MYR ${_formatMoney(
        attraction.nonMalaysianAdultFee,
      )}';
    }

    return 'View Rates';
  }

  // ============================================================
  // ADMISSION RATE POPUP
  // ============================================================

  void _showAdmissionRates(
      BuildContext context,
      ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(
        alpha: 0.35,
      ),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 38,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              15,
              16,
              13,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // =================================================
                // HEADER
                // =================================================
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Admission Rates',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),

                    InkWell(
                      onTap: () {
                        Navigator.pop(
                          dialogContext,
                        );
                      },
                      borderRadius:
                      BorderRadius.circular(20),
                      child: const Padding(
                        padding:
                        EdgeInsets.all(3),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                Text(
                  estimatedFee != null
                      ? 'Your estimated trip fee is MYR ${_formatMoney(estimatedFee!)}.'
                      : 'Standard entrance fees',
                  style: const TextStyle(
                    fontSize: 7.5,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 14),

                // =================================================
                // MALAYSIAN
                // =================================================
                _popupFeeGroup(
                  title: 'Malaysian',
                  adult:
                  attraction.malaysianAdultFee,
                  child:
                  attraction.malaysianChildFee,
                  senior:
                  attraction.malaysianSeniorFee,
                ),

                const SizedBox(height: 13),

                const Divider(
                  height: 1,
                  color: Color(0xFFE6E6E6),
                ),

                const SizedBox(height: 13),

                // =================================================
                // NON-MALAYSIAN
                // =================================================
                _popupFeeGroup(
                  title: 'Non-Malaysian',
                  adult: attraction
                      .nonMalaysianAdultFee,
                  child: attraction
                      .nonMalaysianChildFee,
                  senior: attraction
                      .nonMalaysianSeniorFee,
                ),

                const SizedBox(height: 16),

                // =================================================
                // CLOSE
                // =================================================
                SizedBox(
                  width: double.infinity,
                  height: 35,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(7),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // POPUP FEE GROUP
  // ============================================================

  Widget _popupFeeGroup({
    required String title,
    required double adult,
    required double child,
    required double senior,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: mainGreen,
          ),
        ),

        const SizedBox(height: 9),

        Row(
          children: [
            Expanded(
              child: _popupPrice(
                'Adult',
                adult,
              ),
            ),

            Container(
              width: 1,
              height: 29,
              color: const Color(
                0xFFE7E7E7,
              ),
            ),

            Expanded(
              child: _popupPrice(
                'Child',
                child,
              ),
            ),

            Container(
              width: 1,
              height: 29,
              color: const Color(
                0xFFE7E7E7,
              ),
            ),

            Expanded(
              child: _popupPrice(
                'Senior',
                senior,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // POPUP PRICE ITEM
  // ============================================================

  Widget _popupPrice(
      String label,
      double price,
      ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 7.5,
            color: secondaryText,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          price > 0
              ? 'MYR ${_formatMoney(price)}'
              : '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OPENING HOURS
  // ============================================================

  /// Compact value shown in the quick-information row.
  ///
  /// - If ALL weekly values are empty -> All Day
  /// - If weekly data exists but today is empty -> Closed
  /// - If today has one/multiple periods -> show them
  /// - If isOpen24Hours == true -> All Day
  String _todayOpeningHours() {
    if (attraction.isOpen24Hours) {
      return 'All Day';
    }

    if (!_hasAnyWeeklyOpeningHours()) {
      return 'All Day';
    }

    final String todayKey =
    _weekdayKey(DateTime.now().weekday);

    final List<String> periods =
    _periodsForDay(todayKey);

    if (periods.isEmpty) {
      return 'Closed';
    }

    return periods
        .map(_formatOpeningPeriod)
        .join(', ');
  }

  /// Full Monday-Sunday opening-hours popup.
  void _showWeeklyOpeningHours(
      BuildContext context,
      ) {
    final bool allEmpty =
    !_hasAnyWeeklyOpeningHours();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(
        alpha: 0.35,
      ),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding:
          const EdgeInsets.symmetric(
            horizontal: 34,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(14),
          ),
          child: Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              15,
              16,
              14,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Opening Hours',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(
                          dialogContext,
                        );
                      },
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                      child: const Padding(
                        padding:
                        EdgeInsets.all(3),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color:
                          secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                const Text(
                  'Weekly schedule',
                  style: TextStyle(
                    fontSize: 8,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 14),

                if (attraction.isOpen24Hours ||
                    allEmpty)
                  _allDayNotice()
                else
                  ..._weekdayOrder.map(
                        (day) {
                      final periods =
                      _periodsForDay(
                        day,
                      );

                      final String value =
                      periods.isEmpty
                          ? 'Closed'
                          : periods
                          .map(
                        _formatOpeningPeriod,
                      )
                          .join(
                        '\n',
                      );

                      return Padding(
                        padding:
                        const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 82,
                              child: Text(
                                _weekdayLabel(
                                  day,
                                ),
                                style:
                                const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                value,
                                textAlign:
                                TextAlign.right,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  height: 1.25,
                                  color: periods
                                      .isEmpty
                                      ? const Color(
                                    0xFFB85C5C,
                                  )
                                      : secondaryText,
                                  fontWeight:
                                  periods.isEmpty
                                      ? FontWeight
                                      .w600
                                      : FontWeight
                                      .w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 4),

                SizedBox(
                  width: double.infinity,
                  height: 35,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                      );
                    },
                    style:
                    ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor:
                      mainGreen,
                      foregroundColor:
                      Colors.white,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          7,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _allDayNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius:
        BorderRadius.circular(9),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 18,
            color: mainGreen,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'All Day',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w700,
                    color: mainGreen,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No specific weekly opening hours are provided.',
                  style: TextStyle(
                    fontSize: 7.5,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String>
  _weekdayOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  bool _hasAnyWeeklyOpeningHours() {
    if (attraction.openingHours.isEmpty) {
      return false;
    }

    for (final entry
    in attraction.openingHours.entries) {
      for (final value in entry.value) {
        final clean =
        value.trim().toLowerCase();

        if (clean.isNotEmpty &&
            clean != 'closed') {
          return true;
        }
      }
    }

    return false;
  }

  List<String> _periodsForDay(
      String dayKey,
      ) {
    for (final entry
    in attraction.openingHours.entries) {
      if (entry.key
          .trim()
          .toLowerCase() ==
          dayKey.toLowerCase()) {
        return entry.value
            .map(
              (value) =>
              value.trim(),
        )
            .where(
              (value) =>
          value.isNotEmpty &&
              value.toLowerCase() !=
                  'closed',
        )
            .toList();
      }
    }

    return [];
  }

  String _weekdayKey(int weekday) {
    return _weekdayOrder[
    weekday - 1];
  }

  String _weekdayLabel(String key) {
    if (key.isEmpty) {
      return key;
    }

    return '${key[0].toUpperCase()}'
        '${key.substring(1)}';
  }

  String _formatOpeningPeriod(
      String value,
      ) {
    final parts = value.split(
      RegExp(r'\s*[-–—]\s*'),
    );

    if (parts.length != 2) {
      return value;
    }

    final opening =
    _format24HourTime(
      parts[0],
    );

    final closing =
    _format24HourTime(
      parts[1],
    );

    if (opening.isEmpty ||
        closing.isEmpty) {
      return value;
    }

    return '$opening - $closing';
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _format24HourTime(
      String value,
      ) {
    final String input =
    value.trim();

    if (input.isEmpty) {
      return '';
    }

    // ==========================================================
    // ALREADY 24-HOUR
    // ==========================================================
    final Match? normal24 =
    RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(input);

    if (normal24 != null) {
      final int hour =
          int.tryParse(
            normal24.group(1)!,
          ) ??
              0;

      final String minute =
      normal24.group(2)!;

      return '$hour:$minute';
    }

    // ==========================================================
    // 12-HOUR
    // ==========================================================
    final Match? twelveHour =
    RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(input);

    if (twelveHour != null) {
      int hour =
          int.tryParse(
            twelveHour.group(1)!,
          ) ??
              0;

      final String minute =
      twelveHour.group(2)!;

      final String period =
      twelveHour
          .group(3)!
          .toUpperCase();

      if (period == 'PM' &&
          hour != 12) {
        hour += 12;
      }

      if (period == 'AM' &&
          hour == 12) {
        hour = 0;
      }

      return '$hour:$minute';
    }

    return input;
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _openGoogleMaps(
      BuildContext context,
      ) async {
    final String destination;

    if (attraction.address.trim().isNotEmpty) {
      destination = attraction.address.trim();
    } else {
      destination = '${attraction.name}, ${_locationText()}';
    }

    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/'
          '?api=1'
          '&destination=${Uri.encodeComponent(destination)}'
          '&travelmode=driving',
    );

    final bool launched = await launchUrl(
      googleMapsUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open Google Maps.',
          ),
        ),
      );
    }
  }

  String _locationText() {
    final String area =
    attraction.area.trim();

    final String state =
    attraction.state.trim();

    if (area.isEmpty &&
        state.isEmpty) {
      return 'Location not provided';
    }

    if (area.isEmpty) {
      return state;
    }

    if (state.isEmpty) {
      return area;
    }

    return '$area, $state';
  }

  // ============================================================
  // MONEY
  // ============================================================

  String _formatMoney(
      double value,
      ) {
    if (value ==
        value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // CATEGORY PILL
  // ============================================================

  Widget _pill(
      String text,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: mainGreen,
          fontSize: 8,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _info(
      IconData icon,
      String title,
      String value, {
        String? helperText,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 2,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 19,
            color: mainGreen,
          ),

          const SizedBox(height: 4),

          Text(
            title,
            textAlign:
            TextAlign.center,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 7.2,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            value,
            textAlign:
            TextAlign.center,
            maxLines: 2,
            overflow:
            TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 6.8,
              color: secondaryText,
            ),
          ),

          if (helperText != null &&
              helperText.trim().isNotEmpty) ...[
            const SizedBox(height: 2),

            Text(
              helperText,
              style: const TextStyle(
                fontSize: 5.8,
                color: mainGreen,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ],

          if (!attraction.isFreeEntry &&
              (title == 'Entry Fee' ||
                  title ==
                      'Estimated Fee')) ...[
            const SizedBox(height: 2),

            const Text(
              'Tap to view rates',
              style: TextStyle(
                fontSize: 5.8,
                color: mainGreen,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // HIGHLIGHTS
  // ============================================================

  Widget _list(
      String title,
      IconData icon,
      List<String> values,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: mainGreen,
              size: 15,
            ),

            const SizedBox(width: 5),

            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        if (values.isEmpty)
          const Text(
            'No information available.',
            style: TextStyle(
              fontSize: 8,
              color: secondaryText,
            ),
          )
        else
          ...values.take(6).map(
                (value) {
              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 5,
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Icon(
                      Icons
                          .check_circle_outline_rounded,
                      size: 12,
                      color: mainGreen,
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Expanded(
                      child: Text(
                        value,
                        style:
                        const TextStyle(
                          fontSize: 8,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // FACILITIES
  // ============================================================

  Widget _facilities(
      List<String> values,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              color: mainGreen,
              size: 15,
            ),

            SizedBox(width: 5),

            Text(
              'Facilities',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        if (values.isEmpty)
          const Text(
            'No information available.',
            style: TextStyle(
              fontSize: 8,
              color: secondaryText,
            ),
          )
        else
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children:
            values.take(8).map(
                  (value) {
                return Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration:
                  BoxDecoration(
                    color: lightGreen,
                    borderRadius:
                    BorderRadius
                        .circular(6),
                  ),
                  child: Text(
                    value,
                    style:
                    const TextStyle(
                      fontSize: 7,
                      color: mainGreen,
                    ),
                  ),
                );
              },
            ).toList(),
          ),
      ],
    );
  }
}
