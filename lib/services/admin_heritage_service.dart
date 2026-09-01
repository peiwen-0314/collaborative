import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/heritage_attraction.dart';

class AdminHeritageRecord {
  const AdminHeritageRecord({
    required this.attraction,
    required this.status,
    required this.lastUpdated,
  });

  final HeritageAttraction attraction;
  final String status;
  final DateTime? lastUpdated;
}

class AdminHeritageService {
  AdminHeritageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('heritage_attractions');

  Stream<List<AdminHeritageRecord>> watchHeritagePlaces() {
    return _collection.snapshots().map((snapshot) {
      final records = snapshot.docs.map((doc) {
        final data = doc.data();

        DateTime? lastUpdated;
        final rawUpdated = data['lastUpdated'];

        if (rawUpdated is Timestamp) {
          lastUpdated = rawUpdated.toDate();
        }

        return AdminHeritageRecord(
          attraction: HeritageAttraction.fromFirestore(
            doc.id,
            data,
          ),
          status: data['status']?.toString() ?? 'Active',
          lastUpdated: lastUpdated,
        );
      }).toList();

      records.sort(
            (a, b) => a.attraction.name
            .toLowerCase()
            .compareTo(b.attraction.name.toLowerCase()),
      );

      return records;
    });
  }

  Future<String> generateNextId() async {
    final snapshot = await _collection.get();

    var highest = 0;

    for (final doc in snapshot.docs) {
      final match = RegExp(r'^H(\d+)$').firstMatch(doc.id);

      if (match == null) {
        continue;
      }

      final number = int.tryParse(match.group(1) ?? '');

      if (number != null && number > highest) {
        highest = number;
      }
    }

    return 'H${(highest + 1).toString().padLeft(3, '0')}';
  }

  Future<String> uploadHeritageImage({
    required String documentId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();

    final contentType = _contentTypeFromName(image.name);

    final imageRef = _storage.ref(
      'heritage/$documentId/main_image',
    );

    await imageRef.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
      ),
    );

    return imageRef.getDownloadURL();
  }

  Future<String> addHeritagePlace({
    required Map<String, dynamic> data,
    required XFile image,
  }) async {
    final documentId = await generateNextId();

    final imageUrl = await uploadHeritageImage(
      documentId: documentId,
      image: image,
    );

    await _collection.doc(documentId).set({
      ...data,
      'imageUrl': imageUrl,
      'status': data['status'] ?? 'Active',
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    return documentId;
  }

  Future<void> updateHeritagePlace({
    required String id,
    required Map<String, dynamic> data,
    XFile? newImage,
  }) async {
    String? imageUrl;

    if (newImage != null) {
      imageUrl = await uploadHeritageImage(
        documentId: id,
        image: newImage,
      );
    }

    await _collection.doc(id).update({
      ...data,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHeritagePlace(String id) async {
    // Delete the main Firebase Storage image if it exists.
    try {
      await _storage.ref(
        'heritage/$id/main_image',
      ).delete();
    } on FirebaseException catch (error) {
      // If there is no Storage image, still allow Firestore deletion.
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }

    await _collection.doc(id).delete();
  }

  String _contentTypeFromName(String fileName) {
    final name = fileName.toLowerCase();

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    if (name.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
  }
}
