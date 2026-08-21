import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';
import '../models/shelter.dart';
import '../services/routing_service.dart';
import '../services/shelter_service.dart';

enum PointBeingSet { origin, destination }

class RouteProvider extends ChangeNotifier {
  final RoutingService _service;
  final ShelterService _shelterService;

  RouteProvider({
    required RoutingService service,
    ShelterService? shelterService,
  })  : _service = service,
        _shelterService = shelterService ?? ShelterService();

  LatLng? origin;
  LatLng? destination;
  TravelMode mode = TravelMode.walking;
  PointBeingSet activePoint = PointBeingSet.origin;

  RouteResult? _result;
  bool _isLoading = false;
  String? _error;

  List<Shelter> shelters = [];
  bool isLoadingShelters = false;

  RouteResult? get result => _result;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Request is only meaningful once both points are set.
  bool get canRequestRoute => origin != null && destination != null;

  /// Call once from the screen's init (mirrors IncidentProvider.load() /
  /// AlertProvider.init() elsewhere in the app).
  Future<void> init() async {
    await loadShelters();
  }

  Future<void> loadShelters() async {
    isLoadingShelters = true;
    notifyListeners();
    try {
      shelters = await _shelterService.fetchShelters();
    } catch (_) {
      // Leave whatever shelter list we already had (if any) rather than
      // clearing it on a transient network failure.
    }
    isLoadingShelters = false;
    notifyListeners();
  }

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

  /// Tapping a shelter marker sets it directly as the destination —
  /// shelters are the only valid routing target on this screen, so this
  /// skips the generic tap-to-place flow for destination specifically.
  void selectShelterAsDestination(Shelter shelter) {
    destination = LatLng(shelter.latitude, shelter.longitude);
    _result = null;
    _error = null;
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