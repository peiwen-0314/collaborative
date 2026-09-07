import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attraction_review.dart';
import '../models/attraction.dart';
import '../services/attraction_reviews_service.dart';
import 'review_comments_page.dart';
import 'write_attraction_review_page.dart';

/// Shows every review for one [AttractionModel], with like/comment
/// actions on each, and a FAB to write a new one.
class AttractionReviewsPage extends StatelessWidget {
  const AttractionReviewsPage({super.key, required this.attraction});

  final AttractionModel attraction;

  static const Color green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final service = AttractionReviewsService.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          attraction.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Write a Review'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WriteAttractionReviewPage(attraction: attraction),
            ),
          );
        },
      ),
      body: AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          if (service.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: green),
            );
          }

          if (service.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => service.retry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final reviews = service.reviewsFor(attraction.id);
          if (reviews.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No reviews yet for ${attraction.name}.\nBe the first to share your experience!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _ReviewCard(
                attractionId: attraction.id,
                review: reviews[index],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.attractionId, required this.review});

  final String attractionId;
  final AttractionReview review;

  static const Color green = Color(0xFF2E7D32);
  static const Color likeRed = Color(0xFFE0245E);

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text(
          'This review will be permanently removed. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await AttractionReviewsService.instance.deleteReview(review.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Unable to delete this review. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E5DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: green.withValues(alpha: 0.15),
                child: Text(
                  review.authorName.isNotEmpty
                      ? review.authorName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      review.timeAgo,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 15,
                    color: Colors.amber,
                  );
                }),
              ),
              if (FirebaseAuth.instance.currentUser?.uid == review.userId)
                PopupMenuButton<String>(
                  tooltip: 'Review options',
                  icon: const Icon(Icons.more_vert, color: Colors.black54),
                  onSelected: (value) {
                    if (value == 'delete') _confirmDelete(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete review'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(review.text, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: () => AttractionReviewsService.instance
                    .toggleLike(attractionId, review.id),
                child: Row(
                  children: [
                    Icon(
                      review.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: review.isLiked ? likeRed : Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${review.likes}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: review.isLiked ? likeRed : green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewCommentsPage(
                        attractionId: attractionId,
                        review: review,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 17,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${review.comments.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: green,
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
}
