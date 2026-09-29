import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';

/// Moves [controller]'s map onto the person's current position — what the
/// "my location" button does on every map.
///
/// Uses [live] (the position the screen is already tracking) when there is
/// one; otherwise asks the device for a fresh fix right now, so the button
/// works even before the continuous location stream has produced its first
/// update. If a position can't be found, says why instead of doing nothing.
Future<void> recenterOnUser(
  BuildContext context,
  MapController controller,
  LatLng? live,
) async {
  final messenger = ScaffoldMessenger.of(context);
  var target = live;

  if (target == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Finding your location…'),
        duration: Duration(seconds: 2),
      ));
    target = await LocationService().getCurrentLocation();
  }

  messenger.hideCurrentSnackBar();
  if (target == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text(
        "Couldn't get your location. Make sure location is turned on and "
        'allowed for SafeZone.',
      ),
    ));
    return;
  }

  try {
    final zoom = controller.camera.zoom;
    controller.move(target, zoom < 15 ? 15 : zoom);
  } catch (_) {
    // The map was closed while we were waiting for a fix.
  }
}
