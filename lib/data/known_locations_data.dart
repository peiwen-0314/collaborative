import '../models/location_point.dart';

/// A small fixed gazetteer of Klang Valley / Penang locations used to power
/// the From/To picker's search-as-you-type without needing a paid/keyed
/// geocoding API just to look up a place name. Coordinates are approximate
/// real-world values, accurate enough for demo routing.
const kKnownLocations = <LocationPoint>[
  LocationPoint(name: 'KL Sentral, Kuala Lumpur', lat: 3.1341, lng: 101.6866),
  LocationPoint(name: 'KLCC, Kuala Lumpur', lat: 3.1579, lng: 101.7123),
  LocationPoint(name: 'Rawang, Kuala Lumpur', lat: 3.3172, lng: 101.5764),
  LocationPoint(name: 'Cyberjaya, Kuala Lumpur', lat: 2.9213, lng: 101.6559),
  LocationPoint(
    name: 'Sunway Pyramid, Petaling Jaya',
    lat: 3.0733,
    lng: 101.6067,
  ),
  LocationPoint(name: 'Mid Valley Megamall, Kuala Lumpur', lat: 3.1177, lng: 101.6774),
  LocationPoint(name: 'Batu Caves, Kuala Lumpur', lat: 3.2379, lng: 101.6840),
  LocationPoint(
    name: 'Petaling Jaya, Selangor',
    lat: 3.1073,
    lng: 101.6067,
  ),
  LocationPoint(name: 'Georgetown, Penang', lat: 5.4141, lng: 100.3288),
  LocationPoint(
    name: 'Butterworth Bus Terminal, Penang',
    lat: 5.3991,
    lng: 100.3638,
  ),
  LocationPoint(name: 'Penang International Airport', lat: 5.2971, lng: 100.2769),

  // Real LinkBike (Fast Rent Bike (PG) Sdn. Bhd.) bike-share docking
  // stations - coordinates confirmed live from OpenStreetMap's Overpass API
  // (see tool/list_osm_bike_stations.dart), not estimated. Added here so
  // searching for them in the From/To fields is instant and guaranteed to
  // land exactly on the station's real coordinates, rather than hoping a
  // live Nominatim search for a landmark name happens to resolve within
  // OsmBikeShareService's 1.2km pickup/dropoff radius. Pick one of these as
  // From and a different one as To to reliably see a "Shared Bike" option -
  // Kapitan Keling <-> Gurney Paragon are ~4km apart, a realistic bike trip.
  LocationPoint(name: 'Kapitan Keling (LinkBike Station), George Town', lat: 5.4168246, lng: 100.3377326),
  LocationPoint(name: 'Gurney Paragon / Gurney Drive (LinkBike Station), George Town', lat: 5.4398311, lng: 100.3091867),
  LocationPoint(name: 'Armenian St. (LinkBike Station), George Town', lat: 5.4146961, lng: 100.338474),
  LocationPoint(name: 'Northam Hotel (LinkBike Station), George Town', lat: 5.4273547, lng: 100.3217787),
];

/// Case-insensitive, word-order-independent search over [kKnownLocations].
///
/// This used to check whether the *entire* query appeared as one
/// contiguous substring of the name - which meant typing the words in a
/// different order than they happen to be stored in (e.g. "gurney drive
/// paragon" against a name stored as "Gurney Paragon ... George Town")
/// never matched, even though every word the user typed was a completely
/// reasonable way to refer to that place. Splitting the query into words
/// and requiring each one to appear *somewhere* in the name (in any order)
/// is far more forgiving of exactly that kind of real, honest typing.
List<LocationPoint> searchKnownLocations(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return kKnownLocations;

  final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return kKnownLocations.where((place) {
    final name = place.name.toLowerCase();
    return words.every(name.contains);
  }).toList();
}
