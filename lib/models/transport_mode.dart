import 'package:flutter/material.dart';

import '../core/app_assets.dart';

/// The kind of vehicle/leg used for one segment of a journey.
enum TransportMode { train, mrt, bus, ferry, walk, taxi, bike, other }

extension TransportModeX on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.train:
        return 'Train';
      case TransportMode.mrt:
        return 'MRT';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.ferry:
        return 'Ferry';
      case TransportMode.walk:
        return 'Walk';
      case TransportMode.taxi:
        return 'Taxi';
      case TransportMode.bike:
        return 'Shared Bike';
      case TransportMode.other:
        return 'Transit';
    }
  }

  String? get assetPath {
    switch (this) {
      case TransportMode.train:
        return AppAssets.train;
      case TransportMode.bus:
        return AppAssets.bus;
      case TransportMode.ferry:
        return AppAssets.ferry;
      case TransportMode.mrt:
      case TransportMode.walk:
      case TransportMode.taxi:
      case TransportMode.bike:
      case TransportMode.other:
        return null;
    }
  }

  IconData get icon {
    switch (this) {
      case TransportMode.train:
        return Icons.train_outlined;
      case TransportMode.mrt:
        return Icons.directions_subway_outlined;
      case TransportMode.bus:
        return Icons.directions_bus_outlined;
      case TransportMode.ferry:
        return Icons.directions_boat_outlined;
      case TransportMode.walk:
        return Icons.directions_walk_outlined;
      case TransportMode.taxi:
        return Icons.local_taxi_outlined;
      case TransportMode.bike:
        return Icons.pedal_bike_outlined;
      case TransportMode.other:
        return Icons.commute_outlined;
    }
  }

  Color get routeColor {
    switch (this) {
      case TransportMode.train:
        return const Color(0xFF6A4C93);
      case TransportMode.mrt:
        return const Color(0xFF1E88E5);
      case TransportMode.bus:
        return const Color(0xFF2E7D32);
      case TransportMode.ferry:
        return const Color(0xFF00838F);
      case TransportMode.walk:
        return const Color(0xFFE53935);
      case TransportMode.taxi:
        return const Color(0xFFE07D21);
      case TransportMode.bike:
        return const Color(0xFF00ACC1);
      case TransportMode.other:
        return const Color(0xFF9E9E9E);
    }
  }

  static TransportMode fromHereMode(String? mode) {
    switch (mode) {
      case 'highSpeedTrain':
      case 'intercityTrain':
      case 'interRegionalTrain':
      case 'regionalTrain':
      case 'cityTrain':
      case 'train':
        return TransportMode.train;
      case 'subway':
      case 'lightRail':
      case 'monorail':
        return TransportMode.mrt;
      case 'bus':
      case 'busRapid':
      case 'privateBus':
        return TransportMode.bus;
      case 'ferry':
        return TransportMode.ferry;
      case 'pedestrian':
      case 'walk':
        return TransportMode.walk;
      case 'taxi':
      case 'car':
        return TransportMode.taxi;
      case 'bicycle':
        return TransportMode.bike;
      default:
        return TransportMode.other;
    }
  }

  /// The `transportMode` query value HERE's routing APIs use for the
  /// non-transit fallback we could request (kept for completeness).
  String get hereQueryValue => switch (this) {
    TransportMode.walk => 'pedestrian',
    TransportMode.bike => 'bicycle',
    _ => 'publicTransport',
  };
}

/// Renders either the bundled PNG for [mode] (tinted, matching the rest of
/// the app) or a Material icon fallback when no PNG asset exists.
Widget transportModeGlyph(
  TransportMode mode, {
  double size = 20,
  Color color = Colors.white,
}) {
  final asset = mode.assetPath;
  if (asset != null) {
    return Image.asset(asset, width: size, height: size, color: color);
  }
  return Icon(mode.icon, size: size, color: color);
}
