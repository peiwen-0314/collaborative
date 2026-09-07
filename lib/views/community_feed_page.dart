import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/community_feed_service.dart';
import '../services/community_content_service.dart';
import '../widgets/community_section_switcher.dart';
import '../widgets/eco_bottom_navigation.dart';
import 'ai_trip_planner_page.dart';
import 'attraction_reviews_list_page.dart';
import 'community_post_comments_page.dart';
import 'home_page.dart';
import 'ride_home_page.dart';
import 'write_community_post_page.dart';

/// The general Community module: a social feed of posts (tips and
/// experiences), each with likes and its own comment thread.
///
/// This is the direct Flutter port of the original Kotlin CommunityScreen.
/// Attraction-specific reviews live in a separate area
/// ([AttractionReviewsListPage]) - reachable here via the Reviews button so
/// both are accessible from the Community tab.
class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  static const Color green = Color(0xFF2E7D32);
  static const String allPosts = 'All Posts';

  String _selectedTag = allPosts;

  @override
  void initState() {
    super.initState();
    CommunityContentService.instance.start();
  }

  void _openHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _openTransport() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TransportationPage()),
    );
  }

  void _openPlanTrip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AiTripPlannerPage()),
    );
  }

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttractionReviewsListPage()),
    );
  }

  void _showComingSoon(String page) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$page coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = CommunityFeedService.instance;
    final contentService = CommunityContentService.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      floatingActionButton: FloatingActionButton(
        backgroundColor: green,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WriteCommunityPostPage(
                availableTags: contentService.activeCategoryNames,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([service, contentService]),
        builder: (context, _) {
          final categoryNames = contentService.activeCategoryNames;
          final posts = _selectedTag == allPosts
              ? service.posts
              : service.postsForTag(_selectedTag);

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.luggage_rounded, color: green, size: 25),
                      Transform.translate(
                        offset: const Offset(-7, 7),
                        child: const Icon(Icons.eco, color: green, size: 17),
                      ),
                      const Text(
                        'EcoTravel',
                        style: TextStyle(
                          color: green,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                CommunitySectionSwitcher(
                  showingReviews: false,
                  onCommunityTap: () {},
                  onReviewsTap: _openReviews,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community 🌱',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: green,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Share experiences, tips and inspire responsible travel',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: categoryNames.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tag = index == 0
                          ? allPosts
                          : categoryNames[index - 1];
                      final selected = tag == _selectedTag;
                      return ChoiceChip(
                        label: Text(tag),
                        selected: selected,
                        selectedColor: const Color(0xFFE8F5E9),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: green),
                        labelStyle: TextStyle(
                          color: green,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _selectedTag = tag),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: service.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: green),
                        )
                      : service.errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      service.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
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
                            )
                      : posts.isEmpty
                      ? Center(
                          child: Text(
                            _selectedTag == allPosts
                                ? 'No community posts yet.'
                                : 'No posts under "$_selectedTag" yet.',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
                          itemCount: posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _PostCard(post: posts[index]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: EcoBottomNavigation(
        currentIndex: 3,
        onHomeTap: _openHome,
        onTransportTap: _openTransport,
        onPlanTripTap: _openPlanTrip,
        onCommunityTap: () {
          // Already on the Community page.
        },
        onProfileTap: () => _showComingSoon('Profile'),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final CommunityPost post;

  static const Color green = Color(0xFF2E7D32);
  static const Color likeRed = Color(0xFFE0245E);

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This post will be permanently removed from the community feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await CommunityFeedService.instance.deletePost(post.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Unable to delete this post. Please try again.',
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
                    Text(
                      post.timeAgo,
                      style: const TextStyle(color: Colors.black45, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (FirebaseAuth.instance.currentUser?.uid == post.userId)
                PopupMenuButton<String>(
                  tooltip: 'Post options',
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
                          Text('Delete post'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.text,
            style: const TextStyle(fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: post.imageUrls.length == 1 ? 190 : 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: post.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.imageUrls[index],
                      width: post.imageUrls.length == 1 ? 290 : 150,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: post.imageUrls.length == 1 ? 290 : 150,
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
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: () async {
                  try {
                    await CommunityFeedService.instance.toggleLike(post.id);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error is StateError
                              ? error.message.toString()
                              : 'Unable to update this like.',
                        ),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: post.isLiked ? likeRed : Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likes}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: post.isLiked ? likeRed : green,
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
                      builder: (_) => CommunityPostCommentsPage(post: post),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 17, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentCount}',
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
