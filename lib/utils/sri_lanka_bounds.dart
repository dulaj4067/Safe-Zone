import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// The island plus a small sea margin, so coastal towns (Jaffna, Galle,
/// Trincomalee, Batticaloa) are never pinned against the screen edge.
final LatLngBounds kSriLankaBounds = LatLngBounds(
  const LatLng(5.7, 79.4),
  const LatLng(10.0, 82.1),
);

/// Keeps the map's centre inside Sri Lanka. `containCenter` rather than
/// `contain`: on a tall phone at the minimum zoom the viewport is taller
/// than the island, and `contain` would then reject every camera move.
final CameraConstraint kSriLankaCameraConstraint =
    CameraConstraint.containCenter(bounds: kSriLankaBounds);

/// Roughly the whole island on a phone screen — any further out and the
/// map would just be ocean.
const double kSriLankaMinZoom = 7;
