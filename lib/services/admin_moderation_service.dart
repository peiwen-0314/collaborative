import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

enum ModerationContentType { communityPost, attractionReview }

class AdminModerationItem {
  const AdminModerationItem({
    required this.id,
    required this.type,
    required this.authorName,
    required this.text,
    required this.createdAt,
    required this.status,
    this.rating,
    this.imageUrls = const [],
  });

  final String id;
  final ModerationContentType type;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String status;
  final int? rating;
  final List<String> imageUrls;

  bool get isHidden => status.toLowerCase() == 'hidden';
  String get typeLabel => type == ModerationContentType.communityPost
      ? 'Community Post'
      : 'Attraction Review';
}

class AdminModerationService extends ChangeNotifier {
  AdminModerationService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final List<AdminModerationItem> _posts = [];
  final List<AdminModerationItem> _reviews = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _postsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reviewsSubscription;
  bool _postsLoaded = false;
  bool _reviewsLoaded = false;
  bool _isProcessing = false;
  String? _errorMessage;

  bool get isLoading => !_postsLoaded || !_reviewsLoaded;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  List<AdminModerationItem> get items {
    final all = [..._posts, ..._reviews]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(all);
  }

  int get totalItems => _posts.length + _reviews.length;
  int get visibleItems => items.where((item) => !item.isHidden).length;
  int get hiddenItems => items.where((item) => item.isHidden).length;
  int get communityPosts => _posts.length;
  int get attractionReviews => _reviews.length;

  void start() {
    _postsSubscription ??= _firestore
        .collection('community_posts')
        .snapshots()
        .listen(_loadPosts, onError: _handleError);
    _reviewsSubscription ??= _firestore
        .collection('attraction_reviews')
        .snapshots()
        .listen(_loadReviews, onError: _handleError);
  }

  void _loadPosts(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _posts
      ..clear()
      ..addAll(snapshot.docs.map((document) {
        final data = document.data();
        return AdminModerationItem(
          id: document.id,
          type: ModerationContentType.communityPost,
          authorName: (data['authorName'] ?? 'User').toString(),
          text: (data['text'] ?? '').toString(),
          createdAt: _date(data['createdAt']),
          status: (data['status'] ?? 'Active').toString(),
          imageUrls: _strings(data['imageUrls']),
        );
      }));
    _postsLoaded = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _loadReviews(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _reviews
      ..clear()
      ..addAll(snapshot.docs.map((document) {
        final data = document.data();
        return AdminModerationItem(
          id: document.id,
          type: ModerationContentType.attractionReview,
          authorName: (data['authorName'] ?? 'User').toString(),
          text: (data['text'] ?? '').toString(),
          createdAt: _date(data['createdAt']),
          status: (data['status'] ?? 'Active').toString(),
          rating: (data['rating'] as num?)?.toInt(),
        );
      }));
    _reviewsLoaded = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _handleError(Object _) {
    _postsLoaded = true;
    _reviewsLoaded = true;
    _errorMessage = 'Unable to load moderation content from Firebase.';
    notifyListeners();
  }

  Future<void> setHidden(AdminModerationItem item, bool hidden) async {
    await _runOperation(() async {
      await _collection(item).doc(item.id).update({
        'status': hidden ? 'Hidden' : 'Active',
        'moderatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteItem(AdminModerationItem item) async {
    await _runOperation(() async {
      await _collection(item).doc(item.id).delete();
      if (item.type == ModerationContentType.communityPost) {
        try {
          final folder = _storage.ref().child('community_posts/${item.id}');
          final files = await folder.listAll();
          await Future.wait(files.items.map((file) => file.delete()));
        } catch (_) {
          // The Firestore content is already removed; image cleanup is best effort.
        }
      }
    });
  }

  CollectionReference<Map<String, dynamic>> _collection(
    AdminModerationItem item,
  ) {
    return _firestore.collection(
      item.type == ModerationContentType.communityPost
          ? 'community_posts'
          : 'attraction_reviews',
    );
  }

  Future<void> _runOperation(Future<void> Function() action) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  DateTime _date(dynamic value) {
    return value is Timestamp ? value.toDate() : DateTime.now();
  }

  List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _reviewsSubscription?.cancel();
    super.dispose();
  }
}
