import '../models/location_point.dart';

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
      decodeUnsignedValue();
    }
    points.add(
      LocationPoint(name: '', lat: lat / factorDegree, lng: lng / factorDegree),
    );
  }

  return points;
}

bool looksLikePlausibleRoute(List<LocationPoint> points) {
  if (points.isEmpty) return false;
  for (final point in points) {
    if (point.lat < -10 || point.lat > 25) return false;
    if (point.lng < 90 || point.lng > 130) return false;
  }
  return true;
}
