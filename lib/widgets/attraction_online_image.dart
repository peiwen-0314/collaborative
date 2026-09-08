import 'package:flutter/material.dart';

import '../services/google_places_service.dart';

/// Displays an attraction image using this priority:
/// 1) Firebase / Admin-uploaded image URL
/// 2) Live Google Places photo using googlePlaceId
/// 3) Placeholder
///
/// Google photo bytes and Google photo URLs are NOT persisted to Firebase.
class AttractionOnlineImage extends StatefulWidget {
  final String firebaseImageUrl;
  final String googlePlaceId;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const AttractionOnlineImage({
    super.key,
    required this.firebaseImageUrl,
    required this.googlePlaceId,
    this.width = 56,
    this.height = 48,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(7),
    ),
  });

  @override
  State<AttractionOnlineImage> createState() =>
      _AttractionOnlineImageState();
}

class _AttractionOnlineImageState
    extends State<AttractionOnlineImage> {
  final GooglePlacesService _placesService =
      GooglePlacesService();

  Future<String>? _googlePhotoFuture;

  @override
  void initState() {
    super.initState();
    _prepareGooglePhoto();
  }

  @override
  void didUpdateWidget(
    covariant AttractionOnlineImage oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.googlePlaceId != widget.googlePlaceId ||
        oldWidget.firebaseImageUrl != widget.firebaseImageUrl) {
      _prepareGooglePhoto();
    }
  }

  void _prepareGooglePhoto() {
    // If Admin uploaded a Firebase image, Google is not needed.
    if (widget.firebaseImageUrl.trim().isNotEmpty) {
      _googlePhotoFuture = null;
      return;
    }

    final placeId = widget.googlePlaceId.trim();

    if (placeId.isEmpty) {
      _googlePhotoFuture = null;
      return;
    }

    _googlePhotoFuture =
        _placesService.getFirstPhotoUriForPlace(
      placeId,
      maxWidthPx: 700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUrl =
        widget.firebaseImageUrl.trim();

    if (firebaseUrl.isNotEmpty) {
      return _networkImage(firebaseUrl);
    }

    if (widget.googlePlaceId.trim().isEmpty ||
        _googlePhotoFuture == null) {
      return _placeholder();
    }

    return FutureBuilder<String>(
      future: _googlePhotoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loading();
        }

        final url = snapshot.data?.trim() ?? '';

        if (snapshot.hasError || url.isEmpty) {
          if (snapshot.hasError) {
            debugPrint(
              'Google attraction image error: ${snapshot.error}',
            );
          }

          return _placeholder();
        }

        return _networkImage(
          url,
          preferHtmlElementOnWeb: true,
        );
      },
    );
  }

  Widget _networkImage(
    String url, {
    bool preferHtmlElementOnWeb = false,
  }) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Image.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        webHtmlElementStrategy: preferHtmlElementOnWeb
            ? WebHtmlElementStrategy.prefer
            : WebHtmlElementStrategy.never,
        loadingBuilder: (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return _loading();
        },
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          debugPrint(
            'Attraction image display error: $error',
          );

          return _placeholder();
        },
      ),
    );
  }

  Widget _loading() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: widget.borderRadius,
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 17,
        height: 17,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF0B6B2B),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: widget.borderRadius,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF667085),
      ),
    );
  }
}
