import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/community_post.dart';
import '../models/review_comment.dart';

/// Firestore-backed store for the Community Feed.
///
/// Post metadata is stored in `community_posts`; image files are stored under
/// `community_posts/{postId}` in Firebase Storage. Comments and likes use
/// subcollections beneath their post document.
class CommunityFeedService extends ChangeNotifier {
  CommunityFeedService._internal() {
    _listenToPosts();
  }

  static final CommunityFeedService instance = CommunityFeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final List<CommunityPost> _posts = [];
  final Set<String> _likedPostIds = {};
  final Set<String> _checkedLikePostIds = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _commentSubscriptions = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _postsSubscription;
  bool _isLoading = true;
  String? _errorMessage;

  List<CommunityPost> get posts => List.unmodifiable(_posts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CommunityPost> postsForTag(String tag) {
    return _posts.where((post) => post.tags.contains(tag)).toList();
  }

  void _listenToPosts() {
    _postsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;

    _postsSubscription = _firestore.collection('community_posts').snapshots().listen(
      (snapshot) {
        final oldPosts = {for (final post in _posts) post.id: post};
        final loaded = <_DatedPost>[];

        for (final document in snapshot.docs) {
          final data = document.data();
          final status = (data['status'] ?? 'Active').toString().trim();
          final text = (data['text'] ?? '').toString().trim();
          if (status.toLowerCase() != 'active' || text.isEmpty) continue;

          final createdAtValue = data['createdAt'];
          final createdAt = createdAtValue is Timestamp
              ? createdAtValue.toDate()
              : DateTime.now();
          final previous = oldPosts[document.id];

          final post = CommunityPost(
            id: document.id,
            userId: (data['userId'] ?? '').toString().trim(),
            authorName: (data['authorName'] ?? 'User').toString().trim(),
            timeAgo: _formatTimeAgo(createdAt),
            text: text,
            imageUrls: _stringList(data['imageUrls']),
            tags: _stringList(data['tags']),
            likes: ((data['likeCount'] ?? data['likes']) as num?)?.toInt() ?? 0,
            commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
            status: status,
            isLiked: _likedPostIds.contains(document.id),
            comments: previous?.comments ?? const [],
          );
          loaded.add(_DatedPost(post, createdAt));
        }

        loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final activeIds = loaded.map((item) => item.post.id).toSet();
        final removedIds = _commentSubscriptions.keys
            .where((postId) => !activeIds.contains(postId))
            .toList();
        for (final postId in removedIds) {
          _commentSubscriptions.remove(postId)?.cancel();
        }

        _posts
          ..clear()
          ..addAll(loaded.map((item) => item.post));
        for (final post in _posts) {
          _listenToComments(post.id);
          _loadCurrentUserLike(post.id);
        }
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Unable to load community posts from Firebase.';
        notifyListeners();
      },
    );
  }

  void _listenToComments(String postId) {
    if (_commentSubscriptions.containsKey(postId)) return;
    _commentSubscriptions[postId] = _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .snapshots()
        .listen((snapshot) {
      final datedComments = snapshot.docs.map((document) {
        final data = document.data();
        final value = data['createdAt'];
        final createdAt = value is Timestamp ? value.toDate() : DateTime.now();
        return _DatedComment(
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

      final index = _posts.indexWhere((post) => post.id == postId);
      if (index == -1) return;
      _posts[index] = _posts[index].copyWith(
        comments: datedComments.map((item) => item.comment).toList(),
        commentCount: datedComments.length,
      );
      notifyListeners();
    });
  }

  Future<void> _loadCurrentUserLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null || _checkedLikePostIds.contains(postId)) return;
    _checkedLikePostIds.add(postId);

    try {
      final likeDocument = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('likes')
          .doc(user.uid)
          .get();
      if (likeDocument.exists) {
        _likedPostIds.add(postId);
      } else {
        _likedPostIds.remove(postId);
      }
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          isLiked: likeDocument.exists,
        );
        notifyListeners();
      }
    } catch (_) {
      _checkedLikePostIds.remove(postId);
    }
  }

  Future<void> retry() async {
    await _postsSubscription?.cancel();
    _listenToPosts();
    notifyListeners();
  }

  Future<void> addPost({
    required String authorName,
    required String text,
    List<Uint8List> images = const [],
    required List<String> tags,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to create a post.');
    }

    final postRef = _firestore.collection('community_posts').doc();
    final uploadedImages = <Reference>[];
    final imageUrls = <String>[];

    try {
      for (var index = 0; index < images.length; index++) {
        final imageRef = _storage.ref().child(
              'community_posts/${postRef.id}/image_$index.jpg',
            );
        uploadedImages.add(imageRef);
        await imageRef.putData(
          images[index],
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrls.add(await imageRef.getDownloadURL());
      }

      final resolvedName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email?.split('@').first ?? authorName;

      await postRef.set({
        'userId': user.uid,
        'authorName': resolvedName,
        'text': text.trim(),
        'imageUrls': imageUrls,
        'tags': tags.take(3).toList(),
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
        'status': 'Active',
      });
    } catch (_) {
      for (final imageRef in uploadedImages) {
        try {
          await imageRef.delete();
        } catch (_) {
          // Best-effort cleanup if a later upload or Firestore write fails.
        }
      }
      rethrow;
    }
  }

  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to like a post.');
    }

    final postRef = _firestore.collection('community_posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);
    late bool isNowLiked;

    await _firestore.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      final likeSnapshot = await transaction.get(likeRef);
      if (!postSnapshot.exists) throw StateError('This post no longer exists.');

      final data = postSnapshot.data() ?? <String, dynamic>{};
      final currentCount =
          ((data['likeCount'] ?? data['likes']) as num?)?.toInt() ?? 0;

      if (likeSnapshot.exists) {
        transaction.delete(likeRef);
        transaction.update(postRef, {
          'likeCount': (currentCount - 1).clamp(0, 1 << 31).toInt(),
        });
        isNowLiked = false;
      } else {
        transaction.set(likeRef, {
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'likeCount': currentCount + 1});
        isNowLiked = true;
      }
    });

    if (isNowLiked) {
      _likedPostIds.add(postId);
    } else {
      _likedPostIds.remove(postId);
    }
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(isLiked: isNowLiked);
      notifyListeners();
    }
  }

  /// Deletes a community post only when it belongs to the signed-in user.
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to delete a post.');
    }

    final postRef = _firestore.collection('community_posts').doc(postId);
    final snapshot = await postRef.get();
    if (!snapshot.exists) {
      throw StateError('This post no longer exists.');
    }

    final ownerId = (snapshot.data()?['userId'] ?? '').toString();
    if (ownerId != user.uid) {
      throw StateError('You can only delete your own posts.');
    }

    await postRef.delete();

    // The post is already deleted at this point. Storage cleanup is
    // best-effort so an unavailable image does not make the post reappear.
    try {
      final folder = _storage.ref().child('community_posts/$postId');
      final storedFiles = await folder.listAll();
      await Future.wait(storedFiles.items.map((item) => item.delete()));
    } catch (_) {
      // Ignore missing images or a temporary Storage cleanup failure.
    }

    _likedPostIds.remove(postId);
    _checkedLikePostIds.remove(postId);
    await _commentSubscriptions.remove(postId)?.cancel();
  }

  Future<void> addComment(
    String postId, {
    required String authorName,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to comment.');
    }

    final postRef = _firestore.collection('community_posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();
    final resolvedName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? authorName;
    final batch = _firestore.batch();

    batch.set(commentRef, {
      'userId': user.uid,
      'authorName': resolvedName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'Active',
    });
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to delete a comment.');
    }

    final postRef = _firestore.collection('community_posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final commentSnapshot = await transaction.get(commentRef);
      if (!commentSnapshot.exists) {
        throw StateError('This comment no longer exists.');
      }
      final ownerId =
          (commentSnapshot.data()?['userId'] ?? '').toString().trim();
      if (ownerId != user.uid) {
        throw StateError('You can only delete your own comments.');
      }

      final postSnapshot = await transaction.get(postRef);
      transaction.delete(commentRef);
      if (postSnapshot.exists) {
        final data = postSnapshot.data() ?? <String, dynamic>{};
        final currentCount = (data['commentCount'] as num?)?.toInt() ?? 0;
        transaction.update(postRef, {
          'commentCount': (currentCount - 1).clamp(0, 1 << 31).toInt(),
        });
      }
    });
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
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

class _DatedPost {
  const _DatedPost(this.post, this.createdAt);

  final CommunityPost post;
  final DateTime createdAt;
}

class _DatedComment {
  const _DatedComment(this.comment, this.createdAt);

  final ReviewComment comment;
  final DateTime createdAt;
}
