import 'review_comment.dart';

/// A user-submitted attraction review loaded from Firestore, with a star
/// rating, likes, and its own thread of comments.
class AttractionReview {
  const AttractionReview({
    required this.id,
    required this.attractionId,
    required this.authorName,
    required this.rating,
    required this.text,
    required this.timeAgo,
    this.userId = '',
    this.likes = 0,
    this.isLiked = false,
    this.comments = const [],
  });

  final String id;
  final String attractionId;
  final String authorName;
  final int rating; // 1-5
  final String text;
  final String timeAgo;
  final String userId;
  final int likes;
  final bool isLiked;
  final List<ReviewComment> comments;

  AttractionReview copyWith({
    int? likes,
    bool? isLiked,
    List<ReviewComment>? comments,
  }) {
    return AttractionReview(
      id: id,
      attractionId: attractionId,
      authorName: authorName,
      rating: rating,
      text: text,
      timeAgo: timeAgo,
      userId: userId,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
    );
  }
}
