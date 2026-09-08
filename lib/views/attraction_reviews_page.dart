import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../models/attraction_review.dart';
import '../services/attraction_reviews_service.dart';
import 'write_attraction_review_page.dart';

enum _ReviewFilter {
  all,
  five,
  four,
  three,
  two,
  one,
  withPhotos,
}

class AttractionReviewsPage extends StatefulWidget {
  const AttractionReviewsPage({
    super.key,
    required this.attraction,
  });

  final AttractionModel attraction;

  @override
  State<AttractionReviewsPage> createState() =>
      _AttractionReviewsPageState();
}

class _AttractionReviewsPageState
    extends State<AttractionReviewsPage> {
  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color paleGreen = Color(0xFFE8F5E9);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color secondaryText = Color(0xFF777777);
  static const Color starColor = Color(0xFFFFB300);

  _ReviewFilter _filter = _ReviewFilter.all;

  AttractionReviewsService get _service =>
      AttractionReviewsService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
          ),
        ),
        title: Text(
          widget.attraction.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          if (_service.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: mainGreen,
              ),
            );
          }

          if (_service.errorMessage != null) {
            return _errorView();
          }

          final allReviews =
          _service.reviewsFor(widget.attraction.id);
          final visibleReviews =
          _prepareReviews(allReviews);

          return ListView(
            padding: const EdgeInsets.only(
              bottom: 30,
            ),
            children: [
              _ratingSummary(allReviews),
              _rateWithStars(),
              _filterSection(allReviews),
              if (visibleReviews.isEmpty)
                _emptyState()
              else
                ...visibleReviews.map(
                      (review) => _ReviewCard(
                    attractionId:
                    widget.attraction.id,
                    review: review,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            Text(
              _service.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _service.retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingSummary(
      List<AttractionReview> reviews,
      ) {
    final count = reviews.length;
    final average = count == 0
        ? 0.0
        : reviews.fold<int>(
      0,
          (sum, review) =>
      sum + review.rating,
    ) /
        count;

    final distribution = <int, int>{
      for (var star = 1;
      star <= 5;
      star++)
        star: reviews
            .where(
              (review) =>
          review.rating == star,
        )
            .length,
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Review summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 105,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0
                          ? '—'
                          : average.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 42,
                        height: 1,
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _starRow(
                      average.round(),
                      size: 17,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$count review${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5;
                    star >= 1;
                    star--)
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 3,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              child: Text(
                                '$star',
                                style:
                                const TextStyle(
                                  fontSize: 10,
                                  color:
                                  secondaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child:
                              LinearProgressIndicator(
                                value: count == 0
                                    ? 0
                                    : distribution[
                                star]! /
                                    count,
                                minHeight: 7,
                                borderRadius:
                                BorderRadius.circular(
                                  10,
                                ),
                                backgroundColor:
                                const Color(
                                  0xFFEAEDEA,
                                ),
                                valueColor:
                                const AlwaysStoppedAnimation<
                                    Color>(
                                  starColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateWithStars() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        18,
        17,
        18,
        18,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Rate and review',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share your experience to help other travellers.',
            style: TextStyle(
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _UserAvatar(
                userId:
                FirebaseAuth.instance.currentUser?.uid ??
                    '',
                radius: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
                  children: List.generate(
                    5,
                        (index) {
                      final rating =
                          index + 1;

                      return InkWell(
                        borderRadius:
                        BorderRadius.circular(
                          24,
                        ),
                        onTap: () =>
                            _openWriteReview(
                              rating,
                            ),
                        child: const Padding(
                          padding:
                          EdgeInsets.all(4),
                          child: Icon(
                            Icons
                                .star_border_rounded,
                            size: 34,
                            color:
                            Color(0xFF7B817D),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterSection(
      List<AttractionReview> reviews,
      ) {
    int countFor(int rating) => reviews
        .where(
          (review) =>
      review.rating == rating,
    )
        .length;

    final withPhotos = reviews
        .where(
          (review) =>
      review.photoUrls.isNotEmpty,
    )
        .length;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        18,
        15,
        18,
        14,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  'All',
                  _ReviewFilter.all,
                ),
                _filterChip(
                  '5 ★ ${countFor(5)}',
                  _ReviewFilter.five,
                ),
                _filterChip(
                  '4 ★ ${countFor(4)}',
                  _ReviewFilter.four,
                ),
                _filterChip(
                  '3 ★ ${countFor(3)}',
                  _ReviewFilter.three,
                ),
                _filterChip(
                  '2 ★ ${countFor(2)}',
                  _ReviewFilter.two,
                ),
                _filterChip(
                  '1 ★ ${countFor(1)}',
                  _ReviewFilter.one,
                ),
                _filterChip(
                  'Photos $withPhotos',
                  _ReviewFilter.withPhotos,
                  icon: Icons.photo_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label,
      _ReviewFilter value, {
        IconData? icon,
      }) {
    final selected = _filter == value;

    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
      ),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filter = value;
          });
        },
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? mainGreen
                    : secondaryText,
              ),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: selected
              ? mainGreen
              : const Color(0xFF444444),
        ),
        selectedColor: paleGreen,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected
              ? mainGreen
              .withValues(alpha: 0.35)
              : const Color(0xFFD6DAD6),
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(10),
        ),
      ),
    );
  }

  List<AttractionReview> _prepareReviews(
      List<AttractionReview> source,
      ) {
    var result =
    List<AttractionReview>.from(source);

    switch (_filter) {
      case _ReviewFilter.five:
        result = result
            .where((review) =>
        review.rating == 5)
            .toList();
        break;
      case _ReviewFilter.four:
        result = result
            .where((review) =>
        review.rating == 4)
            .toList();
        break;
      case _ReviewFilter.three:
        result = result
            .where((review) =>
        review.rating == 3)
            .toList();
        break;
      case _ReviewFilter.two:
        result = result
            .where((review) =>
        review.rating == 2)
            .toList();
        break;
      case _ReviewFilter.one:
        result = result
            .where((review) =>
        review.rating == 1)
            .toList();
        break;
      case _ReviewFilter.withPhotos:
        result = result
            .where((review) =>
        review.photoUrls.isNotEmpty)
            .toList();
        break;
      case _ReviewFilter.all:
        break;
    }


    return result;
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        vertical: 44,
        horizontal: 24,
      ),
      child: const Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 38,
            color: Colors.black26,
          ),
          SizedBox(height: 10),
          Text(
            'No reviews match this filter.',
            style: TextStyle(
              fontSize: 12,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _starRow(
      int rating, {
        double size = 16,
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
            (index) => Icon(
          index < rating
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          size: size,
          color: index < rating
              ? starColor
              : const Color(0xFFB9BDBA),
        ),
      ),
    );
  }

  void _openWriteReview(
      int initialRating,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WriteAttractionReviewPage(
              attraction: widget.attraction,
              initialRating: initialRating,
            ),
      ),
    );
  }

}


class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.userId,
    required this.radius,
  });

  final String userId;
  final double radius;

  static const Color mainGreen =
  Color(0xFF2E7D32);
  static const Color lightGreen =
  Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final uid = userId.trim();

    if (uid.isEmpty) {
      return _fallbackAvatar();
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data =
        snapshot.data?.data();

        final photoUrl =
        (data?['photoUrl'] ?? '')
            .toString()
            .trim();

        if (photoUrl.isEmpty) {
          return _fallbackAvatar();
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: lightGreen,
          child: ClipOval(
            child: Image.network(
              photoUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (
                  context,
                  error,
                  stackTrace,
                  ) {
                return _fallbackAvatar(
                  nested: true,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackAvatar({
    bool nested = false,
  }) {
    if (nested) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        color: lightGreen,
        alignment: Alignment.center,
        child: Icon(
          Icons.person_rounded,
          size: radius,
          color: mainGreen,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: lightGreen,
      child: Icon(
        Icons.person_rounded,
        size: radius,
        color: mainGreen,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.attractionId,
    required this.review,
  });

  final String attractionId;
  final AttractionReview review;

  static const Color mainGreen =
  Color(0xFF2E7D32);
  static const Color starColor =
  Color(0xFFFFB300);
  static const Color secondaryText =
  Color(0xFF777777);

  Future<void> _confirmDelete(
      BuildContext context,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
            title: const Text(
              'Delete review?',
            ),
            content: const Text(
              'This review and its uploaded photos will be permanently removed.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      dialogContext,
                      false,
                    ),
                child:
                const Text('Cancel'),
              ),
              FilledButton(
                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  Colors.red,
                ),
                onPressed: () =>
                    Navigator.pop(
                      dialogContext,
                      true,
                    ),
                child:
                const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    try {
      await AttractionReviewsService
          .instance
          .deleteReview(review.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('Review deleted.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Unable to delete this review.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownsReview =
        FirebaseAuth.instance.currentUser
            ?.uid ==
            review.userId;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        18,
        16,
        18,
        16,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _UserAvatar(
                userId: review.userId,
                radius: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style:
                      const TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      review.timeAgo,
                      style:
                      const TextStyle(
                        fontSize: 9,
                        color:
                        secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (ownsReview)
                PopupMenuButton<String>(
                  tooltip:
                  'Review options',
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Colors.black54,
                  ),
                  onSelected: (value) {
                    if (value ==
                        'delete') {
                      _confirmDelete(
                        context,
                      );
                    }
                  },
                  itemBuilder:
                      (context) =>
                  const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_outline,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                              'Delete review'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              ...List.generate(
                5,
                    (index) => Icon(
                  index < review.rating
                      ? Icons.star_rounded
                      : Icons
                      .star_border_rounded,
                  size: 17,
                  color: index <
                      review.rating
                      ? starColor
                      : const Color(
                    0xFFB9BDBA,
                  ),
                ),
              ),
            ],
          ),
          if (review.text
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Color(0xFF303030),
              ),
            ),
          ],
          if (review.photoUrls
              .isNotEmpty) ...[
            const SizedBox(height: 12),
            _PhotoGrid(
              urls: review.photoUrls,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
                onTap: () =>
                    AttractionReviewsService
                        .instance
                        .toggleLike(
                      attractionId,
                      review.id,
                    ),
                child: Padding(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 2,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        review.isLiked
                            ? Icons
                            .favorite_rounded
                            : Icons
                            .favorite_border_rounded,
                        size: 18,
                        color:
                        review.isLiked
                            ? mainGreen
                            : Colors
                            .black54,
                      ),
                      const SizedBox(width: 5),
                      if (review.likes > 0)
                        Text(
                          '${review.likes}',
                          style:
                          const TextStyle(
                            fontSize: 10,
                            color:
                            Color(
                              0xFF4B4B4B,
                            ),
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.urls,
  });

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final shown =
    urls.take(4).toList();

    if (shown.length == 1) {
      return _photo(
        context,
        shown.first,
        height: 185,
        width: double.infinity,
      );
    }

    return SizedBox(
      height: 190,
      child: GridView.builder(
        physics:
        const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 1.45,
        ),
        itemCount: shown.length,
        itemBuilder: (context, index) {
          final remaining =
              urls.length - 4;

          return Stack(
            fit: StackFit.expand,
            children: [
              _photo(
                context,
                shown[index],
              ),
              if (index == 3 &&
                  remaining > 0)
                InkWell(
                  onTap: () =>
                      _openGallery(
                        context,
                        3,
                      ),
                  child: Container(
                    alignment:
                    Alignment.center,
                    color: Colors.black
                        .withValues(
                      alpha: 0.48,
                    ),
                    child: Text(
                      '+$remaining',
                      style:
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _photo(
      BuildContext context,
      String url, {
        double? width,
        double? height,
      }) {
    return InkWell(
      onTap: () {
        final index =
        urls.indexOf(url);
        _openGallery(
          context,
          index < 0 ? 0 : index,
        );
      },
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stack) =>
                Container(
                  color: const Color(
                    0xFFE8F5E9,
                  ),
                  child: const Icon(
                    Icons
                        .broken_image_outlined,
                    color:
                    _AttractionReviewsPageState
                        .mainGreen,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  void _openGallery(
      BuildContext context,
      int initialIndex,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ReviewPhotoGallery(
              urls: urls,
              initialIndex:
              initialIndex,
            ),
      ),
    );
  }
}

class _ReviewPhotoGallery
    extends StatefulWidget {
  const _ReviewPhotoGallery({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ReviewPhotoGallery>
  createState() =>
      _ReviewPhotoGalleryState();
}

class _ReviewPhotoGalleryState
    extends State<
        _ReviewPhotoGallery> {
  late final PageController
  _controller;

  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(
      initialPage:
      widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1}/${widget.urls.length}',
          style:
          const TextStyle(
            fontSize: 15,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (value) {
          setState(() {
            _index = value;
          });
        },
        itemBuilder: (context, index) =>
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.urls[index],
                  fit: BoxFit.contain,
                ),
              ),
            ),
      ),
    );
  }
}
