import '../models/location_point.dart';

/// Decodes HERE's "flexible polyline" format
/// (https://github.com/heremaps/flexible-polyline) into a list of
/// coordinates. HERE's transit routing API returns each route section's
/// real road/rail geometry in this format when `return=polyline` is
/// requested - decoding it is what lets the navigation map follow the
/// actual transportation route instead of drawing a straight line between
/// the origin and destination.
///
/// This was hand-implemented from HERE's published spec in an environment
/// with no Dart SDK and no network access to call the live HERE API, so it
/// could not be run against a real encoded string to confirm it byte-for-
/// byte matches. Every call site wraps this in a try/catch and validates
/// the output with [looksLikePlausibleRoute] before using it, falling back
/// to a straight line if decoding fails or produces coordinates that don't
/// make geographic sense - so a bug here degrades gracefully instead of
/// showing a garbled route.
List<LocationPoint> decodeHereFlexiblePolyline(String encoded) {
  var index = 0;

  int decodeChar(int codeUnit) {
    // Standard base64url alphabet: A-Z=0-25, a-z=26-51, 0-9=52-61, '-'=62,
    // '_'=63.
    if (codeUnit >= 65 && codeUnit <= 90) return codeUnit - 65;
    if (codeUnit >= 97 && codeUnit <= 122) return codeUnit - 97 + 26;
    if (codeUnit >= 48 && codeUnit <= 57) return codeUnit - 48 + 52;
    if (codeUnit == 45) return 62; // '-'
    if (codeUnit == 95) return 63; // '_'
    throw const FormatException('Invalid flexible polyline character');
  }

  int decodeUnsignedValue() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (index >= encoded.length) {
        throw const FormatException('Unexpected end of flexible polyline');
      }
      final value = decodeChar(encoded.codeUnitAt(index));
      index++;
      result |= (value & 0x1F) << shift;
      if ((value & 0x20) == 0) break;
      shift += 5;
    }
    return result;
  }

  int toSigned(int value) {
    if (value & 1 != 0) {
      value = ~value;
    }
    return value >> 1;
  }

  // Header: an unsigned "version" value (must be 1), then a second
  // unsigned value packing precision (bits 0-3) and third-dimension type
  // (bits 4-6) - we only need precision to scale lat/lng, and skip any
  // third dimension (elevation) entirely.
  final version = decodeUnsignedValue();
  if (version != 1) {
    throw FormatException('Unsupported flexible polyline version: $version');
  }
  var headerValue = decodeUnsignedValue();
  final precision = headerValue & 0xF;
  headerValue >>= 4;
  final thirdDimension = headerValue & 0x7;

  var factorDegree = 1.0;
  for (var i = 0; i < precision; i++) {
    factorDegree *= 10;
  }

  var lat = 0;
  var lng = 0;
  final points = <LocationPoint>[];

  while (index < encoded.length) {
    lat += toSigned(decodeUnsignedValue());
    lng += toSigned(decodeUnsignedValue());
    if (thirdDimension != 0) {
      // Decode and discard the third-dimension delta (e.g. elevation) -
      // it still has to be consumed to keep the two coordinate streams
      // aligned, even though this app has no use for it.
      decodeUnsignedValue();
    }
    points.add(
      LocationPoint(name: '', lat: lat / factorDegree, lng: lng / factorDegree),
    );
  }

  return points;
}

/// Very loose sanity check on a decoded path: every point should be
/// roughly within Southeast Asia (generous enough to cover Malaysia,
/// Thailand, Singapore, Indonesia) and the path shouldn't be empty. Used
/// to catch a systematically wrong decode (e.g. a wrong alphabet or scale
/// factor) rather than silently drawing a nonsensical route.
bool looksLikePlausibleRoute(List<LocationPoint> points) {
  if (points.isEmpty) return false;
  for (final point in points) {
    if (point.lat < -10 || point.lat > 25) return false;
    if (point.lng < 90 || point.lng > 130) return false;
  }
  return true;
}
