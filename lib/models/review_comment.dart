/// A single comment left on an [AttractionReview].
class ReviewComment {
  const ReviewComment({
    required this.id,
    required this.authorName,
    required this.text,
    required this.timeAgo,
    this.userId = '',
  });

  final String id;
  final String authorName;
  final String text;
  final String timeAgo;
  final String userId;
}
