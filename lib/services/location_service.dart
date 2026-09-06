import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Thin wrapper around geolocator — handles the permission/service-check
/// dance once, so screens just get a stream of positions or a one-shot
/// fix without repeating that boilerplate.
class LocationService {
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Live position updates for an always-on-map "you are here" marker.
  /// distanceFilter avoids rebuild spam from GPS jitter while stationary.
  Stream<LatLng> watchPosition() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => LatLng(p.latitude, p.longitude));
  }

  /// One-shot fix — e.g. for a "use my location" button.
  Future<LatLng?> getCurrentLocation() async {
    final granted = await ensurePermission();
    if (!granted) return null;
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }
}