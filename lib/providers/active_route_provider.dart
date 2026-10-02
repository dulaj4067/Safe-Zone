import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';
import '../models/shelter.dart';

/// The safe route most recently worked out on the directions screen, so
/// the home map can keep showing it after the person leaves that screen.
class ActiveRoute {
  final RouteResult result;
  final LatLng destination;
  final TravelMode mode;

  /// The shelter being routed to, or null for a tapped custom point.
  final Shelter? shelter;

  const ActiveRoute({
    required this.result,
    required this.destination,
    required this.mode,
    this.shelter,
  });
}

class ActiveRouteProvider extends ChangeNotifier {
  ActiveRoute? _route;

  ActiveRoute? get route => _route;

  void set(ActiveRoute route) {
    _route = route;
    notifyListeners();
  }

  void clear() {
    if (_route == null) return;
    _route = null;
    notifyListeners();
  }
}
