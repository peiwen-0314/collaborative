import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ReviewPhotoService {
  ReviewPhotoService._();

  static final ReviewPhotoService instance =
      ReviewPhotoService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> uploadReviewPhotos({
    required String attractionId,
    required List<XFile> photos,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Please login before uploading review photos.',
      );
    }

    if (photos.isEmpty) {
      return const <String>[];
    }

    final urls = <String>[];
    final batchId =
        DateTime.now().microsecondsSinceEpoch.toString();

    for (var index = 0; index < photos.length; index++) {
      final photo = photos[index];
      final bytes = await photo.readAsBytes();

      if (bytes.isEmpty) {
        continue;
      }

      final extension = _extension(photo.name);
      final contentType = _contentType(extension);

      final ref = _storage
          .ref()
          .child('review_photos')
          .child(user.uid)
          .child(attractionId)
          .child('${batchId}_$index.$extension');

      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'userId': user.uid,
            'attractionId': attractionId,
          },
        ),
      );

      urls.add(
        await ref.getDownloadURL(),
      );
    }

    return urls;
  }

  Future<void> deletePhotos(
    List<String> urls,
  ) async {
    for (final url in urls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // The review can still be deleted even if one old photo is missing.
      }
    }
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');

    if (dot == -1 ||
        dot == fileName.length - 1) {
      return 'jpg';
    }

    final ext = fileName
        .substring(dot + 1)
        .toLowerCase();

    if (ext == 'png' ||
        ext == 'webp' ||
        ext == 'jpeg' ||
        ext == 'jpg') {
      return ext;
    }

    return 'jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
