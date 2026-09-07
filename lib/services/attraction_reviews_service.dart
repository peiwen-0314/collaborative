import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/attraction_review.dart';
import '../models/review_comment.dart';

/// Firestore-backed, app-wide store for attraction reviews.
///
/// Reviews are kept in the top-level `attraction_reviews` collection and
/// grouped locally by `attractionId`. Average ratings and review counts are
/// calculated from these documents, so the `attractions` collection is never
/// modified by this module.
class AttractionReviewsService extends ChangeNotifier {
  AttractionReviewsService._internal() {
    _listenToReviews();
  }

  static final AttractionReviewsService instance =
      AttractionReviewsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, List<AttractionReview>> _reviewsByAttraction = {};
  final Set<String> _likedReviewIds = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _commentSubscriptions = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _isLoading = true;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AttractionReview> reviewsFor(String attractionId) {
    return List.unmodifiable(_reviewsByAttraction[attractionId] ?? const []);
  }

  int reviewCountFor(String attractionId) {
    return _reviewsByAttraction[attractionId]?.length ?? 0;
  }

  double averageRatingFor(String attractionId) {
    final reviews = _reviewsByAttraction[attractionId];
    if (reviews == null || reviews.isEmpty) return 0;

    final total = reviews.fold<int>(
      0,
      (sum, review) => sum + review.rating,
    );
    return total / reviews.length;
  }

  void _listenToReviews() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;

    _subscription =
        _firestore.collection('attraction_reviews').snapshots().listen(
      (snapshot) {
        final previousReviews = <String, AttractionReview>{};
        for (final reviews in _reviewsByAttraction.values) {
          for (final review in reviews) {
            previousReviews[review.id] = review;
          }
        }

        final grouped = <String, List<_DatedReview>>{};
        for (final document in snapshot.docs) {
          final data = document.data();
          final attractionId = (data['attractionId'] ?? '').toString().trim();
          final text = (data['text'] ?? '').toString().trim();
          final status = (data['status'] ?? 'Active').toString().trim();
          if (attractionId.isEmpty ||
              text.isEmpty ||
              status.toLowerCase() != 'active') {
            continue;
          }

          final createdAtValue = data['createdAt'];
          final createdAt = createdAtValue is Timestamp
              ? createdAtValue.toDate()
              : DateTime.now();
          final oldReview = previousReviews[document.id];
          final review = AttractionReview(
            id: document.id,
            attractionId: attractionId,
            userId: (data['userId'] ?? '').toString().trim(),
            authorName: (data['authorName'] ?? 'User').toString().trim(),
            rating: ((data['rating'] as num?)?.toInt() ?? 0)
                .clamp(1, 5)
                .toInt(),
            text: text,
            timeAgo: _formatTimeAgo(createdAt),
            likes: (data['likes'] as num?)?.toInt() ?? 0,
            isLiked: _likedReviewIds.contains(document.id),
            comments: oldReview?.comments ?? const [],
          );
          grouped
              .putIfAbsent(attractionId, () => [])
              .add(_DatedReview(review, createdAt));
        }

        _reviewsByAttraction
          ..clear()
          ..addEntries(
            grouped.entries.map((entry) {
              entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return MapEntry(
                entry.key,
                entry.value.map((item) => item.review).toList(),
              );
            }),
          );
        final activeReviewIds = _reviewsByAttraction.values
            .expand((reviews) => reviews)
            .map((review) => review.id)
            .toSet();
        final removedReviewIds = _commentSubscriptions.keys
            .where((reviewId) => !activeReviewIds.contains(reviewId))
            .toList();
        for (final reviewId in removedReviewIds) {
          _commentSubscriptions.remove(reviewId)?.cancel();
        }
        for (final entry in _reviewsByAttraction.entries) {
          for (final review in entry.value) {
            _listenToComments(entry.key, review.id);
          }
        }
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Unable to load reviews from Firebase.';
        notifyListeners();
      },
    );
  }

  void _listenToComments(String attractionId, String reviewId) {
    if (_commentSubscriptions.containsKey(reviewId)) return;
    _commentSubscriptions[reviewId] = _firestore
        .collection('attraction_reviews')
        .doc(reviewId)
        .collection('comments')
        .snapshots()
        .listen((snapshot) {
      final datedComments = snapshot.docs.map((document) {
        final data = document.data();
        final createdAtValue = data['createdAt'];
        final createdAt = createdAtValue is Timestamp
            ? createdAtValue.toDate()
            : DateTime.now();
        return _DatedReviewComment(
          ReviewComment(
            id: document.id,
            userId: (data['userId'] ?? '').toString().trim(),
            authorName: (data['authorName'] ?? 'User').toString().trim(),
            text: (data['text'] ?? '').toString().trim(),
            timeAgo: _formatTimeAgo(createdAt),
          ),
          createdAt,
        );
      }).where((item) => item.comment.text.isNotEmpty).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final reviews = _reviewsByAttraction[attractionId];
      if (reviews == null) return;
      final index = reviews.indexWhere((review) => review.id == reviewId);
      if (index == -1) return;
      reviews[index] = reviews[index].copyWith(
        comments: datedComments.map((item) => item.comment).toList(),
      );
      notifyListeners();
    });
  }

  Future<void> retry() async {
    await _subscription?.cancel();
    _listenToReviews();
    notifyListeners();
  }

  /// Creates a document using the fields in `attraction_reviews`.
  Future<void> addReview({
    required String attractionId,
    required String authorName,
    required int rating,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to submit a review.');
    }

    final resolvedName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? authorName;

    await _firestore.collection('attraction_reviews').add({
      'attractionId': attractionId,
      'userId': user.uid,
      'authorName': resolvedName,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'rating': rating.clamp(1, 5).toInt(),
      'text': text.trim(),
      'status': 'Active',
    });
  }

  Future<void> toggleLike(String attractionId, String reviewId) async {
    final list = _reviewsByAttraction[attractionId];
    if (list == null) return;
    final index = list.indexWhere((review) => review.id == reviewId);
    if (index == -1) return;

    final review = list[index];
    final wasLiked = _likedReviewIds.contains(reviewId);
    final newLikes = (review.likes + (wasLiked ? -1 : 1))
        .clamp(0, 1 << 31)
        .toInt();

    if (wasLiked) {
      _likedReviewIds.remove(reviewId);
    } else {
      _likedReviewIds.add(reviewId);
    }
    list[index] = review.copyWith(isLiked: !wasLiked, likes: newLikes);
    notifyListeners();

    try {
      await _firestore
          .collection('attraction_reviews')
          .doc(reviewId)
          .update({'likes': newLikes});
    } catch (_) {
      if (wasLiked) {
        _likedReviewIds.add(reviewId);
      } else {
        _likedReviewIds.remove(reviewId);
      }
      list[index] = review;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteReview(String reviewId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to delete a review.');
    }

    final reviewRef = _firestore.collection('attraction_reviews').doc(reviewId);
    final snapshot = await reviewRef.get();
    if (!snapshot.exists) {
      throw StateError('This review no longer exists.');
    }
    final ownerId = (snapshot.data()?['userId'] ?? '').toString().trim();
    if (ownerId != user.uid) {
      throw StateError('You can only delete your own reviews.');
    }
    await reviewRef.delete();
    _likedReviewIds.remove(reviewId);
    await _commentSubscriptions.remove(reviewId)?.cancel();
  }

  Future<void> addComment(
    String attractionId,
    String reviewId, {
    required String authorName,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to comment.');
    }
    final resolvedName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? authorName;
    await _firestore
        .collection('attraction_reviews')
        .doc(reviewId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'authorName': resolvedName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'Active',
    });
  }

  Future<void> deleteComment(
    String attractionId,
    String reviewId,
    String commentId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to delete a comment.');
    }
    final commentRef = _firestore
        .collection('attraction_reviews')
        .doc(reviewId)
        .collection('comments')
        .doc(commentId);
    final snapshot = await commentRef.get();
    if (!snapshot.exists) throw StateError('This comment no longer exists.');
    final ownerId = (snapshot.data()?['userId'] ?? '').toString().trim();
    if (ownerId != user.uid) {
      throw StateError('You can only delete your own comments.');
    }
    await commentRef.delete();
  }

  String _formatTimeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hrs ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DatedReview {
  const _DatedReview(this.review, this.createdAt);

  final AttractionReview review;
  final DateTime createdAt;
}

class _DatedReviewComment {
  const _DatedReviewComment(this.comment, this.createdAt);

  final ReviewComment comment;
  final DateTime createdAt;
}
