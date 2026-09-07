import 'review_comment.dart';

/// A general community post (not tied to a specific attraction) - the
/// "Community" module: a social feed of tips/experiences, taggable and
/// filterable, with its own likes and comment thread.
///
/// This is distinct from [AttractionReview] (see attraction_review.dart),
/// which is a rated write-up scoped to one HeritageAttraction. Both live
/// under the app's Community area: CommunityFeedPage for this, and
/// AttractionReviewsListPage for that.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.timeAgo,
    required this.text,
    this.userId = '',
    this.imageUrls = const [],
    this.tags = const [],
    this.likes = 0,
    this.commentCount = 0,
    this.status = 'Active',
    this.isLiked = false,
    this.comments = const [],
  });

  final String id;
  final String authorName;
  final String timeAgo;
  final String text;
  final String userId;
  final List<String> imageUrls;
  final List<String> tags;
  final int likes;
  final int commentCount;
  final String status;
  final bool isLiked;
  final List<ReviewComment> comments;

  CommunityPost copyWith({
    int? likes,
    int? commentCount,
    bool? isLiked,
    List<ReviewComment>? comments,
  }) {
    return CommunityPost(
      id: id,
      authorName: authorName,
      timeAgo: timeAgo,
      text: text,
      userId: userId,
      imageUrls: imageUrls,
      tags: tags,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      status: status,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
    );
  }
}
