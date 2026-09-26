import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../utils/map_tile_config.dart';
import '../../../utils/map_tile_sources.dart';
import '../models/evacuation_route.dart';
import '../providers/preparedness_provider.dart';

class EvacuationMapScreen extends StatefulWidget {
  const EvacuationMapScreen({super.key, required this.zoneId});
  final String zoneId;

  @override
  State<EvacuationMapScreen> createState() => _EvacuationMapScreenState();
}

class _EvacuationMapScreenState extends State<EvacuationMapScreen> {
  final _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _location;
  bool _locationUnavailable = false;
  String? _activeAlert;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PreparednessProvider>();
      await provider.load();
      if (!mounted) return;
      _activeAlert = await provider.getActiveAlertForZone(widget.zoneId);
      if (mounted) setState(() {});
      await _watchLocation();
    });
  }

  Future<void> _watchLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationUnavailable = true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationUnavailable = true);
        return;
      }
      final current = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _location = LatLng(current.latitude, current.longitude));
      _positionSubscription = Geolocator.getPositionStream().listen((position) {
        if (mounted) setState(() => _location = LatLng(position.latitude, position.longitude));
      });
    } catch (_) {
      if (mounted) setState(() => _locationUnavailable = true);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreparednessProvider>();
    final candidates = provider.routes.where((route) => route.zoneId == widget.zoneId || route.zoneId == 'default').toList();
    final route = _nearestRoute(candidates, _location);
    final center = _location ?? route?.startPoint ?? const LatLng(6.9344, 79.8500);

    return Scaffold(
      appBar: AppBar(title: const Text('Evacuation map')),
      body: Column(
        children: [
          if (_locationUnavailable)
            const MaterialBanner(
              content: Text('Location unavailable. Showing the zone route.'),
              actions: [SizedBox.shrink()],
            ),
          if (_activeAlert != null)
            MaterialBanner(
              content: Text('Active alert: $_activeAlert. Follow authority instructions.'),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 14),
                  children: [
                    buildBaseTileLayer(BaseMapStyle.topo),
                    if (route != null && route.routePolyline.length > 1)
                      PolylineLayer(polylines: [Polyline(points: route.routePolyline, strokeWidth: 6, color: Theme.of(context).colorScheme.primary)]),
                    MarkerLayer(
                      markers: [
                        if (_location != null)
                          Marker(
                            point: _location!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                          ),
                        if (route != null)
                          Marker(
                            point: route.safeZonePoint,
                            width: 44,
                            height: 48,
                            child: const Icon(Icons.health_and_safety, color: Colors.green, size: 38),
                          ),
                      ],
                    ),
                    RichAttributionWidget(attributions: [TextSourceAttribution(attributionFor(BaseMapStyle.topo))]),
                  ],
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'my-location',
                    tooltip: 'Center on my location',
                    onPressed: _location == null ? null : () => _mapController.move(_location!, 15),
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: route == null
                ? const Center(child: Text('No evacuation route is available for this zone yet.'))
                : _RouteInstructions(route: route),
          ),
        ],
      ),
    );
  }

  EvacuationRoute? _nearestRoute(List<EvacuationRoute> routes, LatLng? location) {
    if (routes.isEmpty) return null;
    if (location == null) return routes.first;
    routes.sort((a, b) => const Distance().as(LengthUnit.Meter, location, a.safeZonePoint)
        .compareTo(const Distance().as(LengthUnit.Meter, location, b.safeZonePoint)));
    return routes.first;
  }
}

class _RouteInstructions extends StatelessWidget {
  const _RouteInstructions({required this.route});
  final EvacuationRoute route;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text('Recommended safe route', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Updated ${MaterialLocalizations.of(context).formatShortDate(route.lastUpdated)}'),
          const SizedBox(height: 10),
          if (route.instructions.isEmpty)
            const Text('Follow the highlighted route to the marked safe zone.')
          else
            ...route.instructions.asMap().entries.map((entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 14, child: Text('${entry.key + 1}')),
                  title: Text(entry.value),
                )),
        ],
      );
}