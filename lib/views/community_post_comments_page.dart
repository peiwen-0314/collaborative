import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/community_feed_service.dart';
import '../services/profanity_filter_service.dart';

/// Comment thread for a [CommunityPost]. Mirrors ReviewCommentsPage - same
/// filter-on-submit pattern, applied here to the general feed instead of
/// attraction reviews.
class CommunityPostCommentsPage extends StatefulWidget {
  const CommunityPostCommentsPage({super.key, required this.post});

  final CommunityPost post;

  @override
  State<CommunityPostCommentsPage> createState() =>
      _CommunityPostCommentsPageState();
}

class _CommunityPostCommentsPageState extends State<CommunityPostCommentsPage> {
  static const Color green = Color(0xFF2E7D32);

  final TextEditingController _commentController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final result = await ProfanityFilterService.check(text);
    if (!mounted) return;
    if (result.errorMessage != null) {
      setState(() => _errorText = result.errorMessage);
      return;
    }
    if (result.isFlagged) {
      setState(() {
        _errorText =
            "That comment contains language that isn't allowed. Please rephrase.";
      });
      return;
    }

    try {
      await CommunityFeedService.instance.addComment(
        widget.post.id,
        authorName: 'You',
        text: text,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() => _errorText = null);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error is StateError
            ? error.message.toString()
            : 'Unable to save your comment. Please try again.';
      });
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await _confirmDeletion('Delete comment?');
    if (!confirmed) return;
    try {
      await CommunityFeedService.instance.deleteComment(
        widget.post.id,
        commentId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error is StateError
            ? error.message.toString()
            : 'Unable to delete this comment. Please try again.';
      });
    }
  }

  Future<bool> _confirmDeletion(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final service = CommunityFeedService.instance;
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
                final current = service.posts.firstWhere(
                  (post) => post.id == widget.post.id,
                  orElse: () => widget.post,
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  children: [
                    _OriginalPost(post: current),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      '${current.comments.length} comment${current.comments.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
                        style: const TextStyle(color: Color(0xFFB3261E), fontSize: 11.5),
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
                        onPressed: _submitComment,
                        icon: const Icon(Icons.send, color: green),
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

class _OriginalPost extends StatelessWidget {
  const _OriginalPost({required this.post});

  final CommunityPost post;

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
            post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
            style: const TextStyle(color: green, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                post.text,
                style: const TextStyle(fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
              ),
              if (post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post.imageUrls[index],
                          width: 180,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 180,
                            height: 150,
                            color: const Color(0xFFE8F5E9),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: post.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: green,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
