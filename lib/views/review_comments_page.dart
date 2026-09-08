import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/attraction_review.dart';
import '../services/attraction_reviews_service.dart';
import '../services/review_moderation_service.dart';

/// Shows the original review for context, its comment thread, and an
/// add-comment box. Every submitted comment is checked using the same
/// API moderation service as attraction reviews before being saved.
class ReviewCommentsPage extends StatefulWidget {
  const ReviewCommentsPage({
    super.key,
    required this.attractionId,
    required this.review,
  });

  final String attractionId;
  final AttractionReview review;

  @override
  State<ReviewCommentsPage> createState() => _ReviewCommentsPageState();
}

class _ReviewCommentsPageState extends State<ReviewCommentsPage> {
  static const Color green = Color(0xFF2E7D32);

  final TextEditingController _commentController = TextEditingController();
  String? _errorText;
  bool _submittingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();

    if (text.isEmpty || _submittingComment) {
      return;
    }

    setState(() {
      _submittingComment = true;
      _errorText = null;
    });

    try {
      // =====================================================
      // 1. API CONTENT MODERATION
      // =====================================================
      final moderationResult =
      await ReviewModerationService.instance.moderate(text);

      if (!mounted) return;

      if (!moderationResult.allowed) {
        setState(() {
          _submittingComment = false;
          _errorText =
          moderationResult.source == 'google-moderation'
              ? 'That comment contains inappropriate content. Please rephrase.'
              : (moderationResult.message.isNotEmpty
              ? moderationResult.message
              : 'Unable to check this comment right now. Please try again.');
        });
        return;
      }

      // =====================================================
      // 2. MODERATION PASSED -> SAVE COMMENT
      // =====================================================
      await AttractionReviewsService.instance.addComment(
        widget.attractionId,
        widget.review.id,
        authorName: 'You',
        text: text,
      );

      if (!mounted) return;

      _commentController.clear();

      setState(() {
        _submittingComment = false;
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _submittingComment = false;
        _errorText = error is StateError
            ? error.message.toString()
            : 'Unable to save your comment. Please try again.';
      });
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
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
    if (confirmed != true || !mounted) return;

    try {
      await AttractionReviewsService.instance.deleteComment(
        widget.attractionId,
        widget.review.id,
        commentId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error is StateError
            ? error.message.toString()
            : 'Unable to delete this comment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = AttractionReviewsService.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Comments', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: service,
              builder: (context, _) {
                final currentReviews = service.reviewsFor(widget.attractionId);
                final current = currentReviews.firstWhere(
                      (r) => r.id == widget.review.id,
                  orElse: () => widget.review,
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  children: [
                    _OriginalReview(review: current),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      '${current.comments.length} comment${current.comments.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (current.comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No comments yet - be the first to share your thoughts!',
                          style: TextStyle(color: Colors.black54, fontSize: 12.5),
                        ),
                      ),
                    ...current.comments.map(
                          (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: green.withValues(alpha: 0.15),
                              child: Text(
                                comment.authorName.isNotEmpty
                                    ? comment.authorName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.authorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        comment.timeAgo,
                                        style: const TextStyle(
                                          color: Colors.black45,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment.text,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            if (FirebaseAuth.instance.currentUser?.uid ==
                                comment.userId)
                              IconButton(
                                tooltip: 'Delete comment',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteComment(comment.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Color(0xFFB3261E),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            filled: true,
                            fillColor: const Color(0xFFF0F0F0),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() => _errorText = null);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed:
                        _submittingComment ? null : _submitComment,
                        icon: _submittingComment
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: green,
                          ),
                        )
                            : const Icon(
                          Icons.send,
                          color: green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginalReview extends StatelessWidget {
  const _OriginalReview({required this.review});

  final AttractionReview review;

  static const Color green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: green.withValues(alpha: 0.15),
          child: Text(
            review.authorName.isNotEmpty
                ? review.authorName[0].toUpperCase()
                : '?',
            style: const TextStyle(color: green, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    review.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(
                      5,
                          (i) => Icon(
                        i < review.rating ? Icons.star : Icons.star_border,
                        size: 12,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(review.text, style: const TextStyle(fontSize: 13, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
