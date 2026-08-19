import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_result.dart';
import '../services/routing_service.dart';

enum PointBeingSet { origin, destination }

class RouteProvider extends ChangeNotifier {
  final RoutingService _service;

  RouteProvider({required RoutingService service}) : _service = service;

  LatLng? origin;
  LatLng? destination;
  TravelMode mode = TravelMode.walking;
  PointBeingSet activePoint = PointBeingSet.origin;

  RouteResult? _result;
  bool _isLoading = false;
  String? _error;

  RouteResult? get result => _result;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Story 5 AC: request is only meaningful once both points are set.
  bool get canRequestRoute => origin != null && destination != null;

  void setActivePoint(PointBeingSet point) {
    activePoint = point;
    notifyListeners();
  }

  /// Called on map tap — places whichever point is currently "active" and
  /// auto-advances to destination after origin is set, so a citizen can
  /// place both points with two taps and no extra screens.
  void setPointFromTap(LatLng point) {
    if (activePoint == PointBeingSet.origin) {
      origin = point;
      activePoint = PointBeingSet.destination;
    } else {
      destination = point;
    }
    _result = null;
    _error = null;
    notifyListeners();
  }

  void setOriginToCurrentLocation(LatLng current) {
    origin = current;
    activePoint = PointBeingSet.destination;
    notifyListeners();
  }

  void setMode(TravelMode newMode) {
    mode = newMode;
    if (_result != null && canRequestRoute) {
      requestRoute();
    } else {
      notifyListeners();
    }
  }

  Future<void> requestRoute() async {
    if (!canRequestRoute) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _result = await _service.fetchRoute(
        origin: origin!,
        destination: destination!,
        mode: mode,
      );
    } catch (e) {
      _result = null;
      _error = e is RouteException ? e.message : 'Could not fetch a route.';
    }

    _isLoading = false;
    notifyListeners();
  }

  void reset() {
    origin = null;
    destination = null;
    activePoint = PointBeingSet.origin;
    _result = null;
    _error = null;
    notifyListeners();
  }
}
