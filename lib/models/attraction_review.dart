import 'review_comment.dart';

class AttractionReview {
  const AttractionReview({
    required this.id,
    required this.attractionId,
    required this.userId,
    required this.authorName,
    required this.rating,
    required this.text,
    required this.timeAgo,
    this.likes = 0,
    this.isLiked = false,
    this.comments = const <ReviewComment>[],
    this.photoUrls = const <String>[],
  });

  final String id;
  final String attractionId;
  final String userId;
  final String authorName;
  final int rating;
  final String text;
  final String timeAgo;
  final int likes;
  final bool isLiked;
  final List<ReviewComment> comments;

  /// Firebase Storage download URLs uploaded with this review.
  final List<String> photoUrls;

  AttractionReview copyWith({
    String? id,
    String? attractionId,
    String? userId,
    String? authorName,
    int? rating,
    String? text,
    String? timeAgo,
    int? likes,
    bool? isLiked,
    List<ReviewComment>? comments,
    List<String>? photoUrls,
  }) {
    return AttractionReview(
      id: id ?? this.id,
      attractionId: attractionId ?? this.attractionId,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      rating: rating ?? this.rating,
      text: text ?? this.text,
      timeAgo: timeAgo ?? this.timeAgo,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }
}
