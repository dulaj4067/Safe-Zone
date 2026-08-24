import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/route_result.dart';
import '../models/shelter.dart';
import '../providers/route_provider.dart';
import '../services/routing_service.dart';
import '../utils/map_tile_sources.dart';
import '../widgets/location_alert_banner.dart';
import '../widgets/map_controls.dart';
import '../widgets/route_summary_card.dart';

/// Combines "request a route between two points" and "display the
/// suggested route on a map" into one screen. Only shelters are shown as
/// possible destinations — tapping a shelter marker sets it as the
/// destination directly; tapping empty map sets the origin.
class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // TODO: move this key into your existing app config / --dart-define
      // setup rather than hardcoding it here.
      create: (_) => RouteProvider(
        service: RoutingService(apiKey: 'YOUR_DIRECTIONS_API_KEY'),
      ),
      child: const _RouteScreenBody(),
    );
  }
}

class _RouteScreenBody extends StatefulWidget {
  const _RouteScreenBody();

  @override
  State<_RouteScreenBody> createState() => _RouteScreenBodyState();
}

class _RouteScreenBodyState extends State<_RouteScreenBody> {
  static const LatLng _initialCenter = LatLng(6.9615, 79.9010);

  final MapController _mapController = MapController();
  BaseMapStyle _baseMapStyle = BaseMapStyle.street;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteProvider>().init();
    });
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _toggleBaseMapStyle() {
    setState(() {
      _baseMapStyle = _baseMapStyle == BaseMapStyle.street ? BaseMapStyle.topo : BaseMapStyle.street;
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    final provider = context.read<RouteProvider>();
    // Only origin can be placed by tapping empty map — destination must be
    // a shelter (see _onShelterTap).
    if (provider.activePoint == PointBeingSet.origin) {
      provider.setOriginToCurrentLocation(point);
    }
  }

  Future<void> _onShelterTap(Shelter shelter) async {
    final provider = context.read<RouteProvider>();
    provider.selectShelterAsDestination(shelter);
    if (provider.canRequestRoute) {
      await provider.requestRoute();
      final result = provider.result;
      if (result != null) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: result.bounds, padding: const EdgeInsets.all(60)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route to safety'),
        actions: [
          if (provider.origin != null || provider.destination != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Reset',
              onPressed: () => context.read<RouteProvider>().reset(),
            ),
        ],
      ),
      body: Column(
        children: [
          // TODO: replace _initialCenter with the device's real GPS
          // position once location permissions are wired up (see the
          // TODO in LocationAlertBanner itself).
          LocationAlertBanner(
            userLocation: _initialCenter,
            onTap: () {
              // TODO: navigate to a full alert-detail screen.
            },
          ),
          _ModeAndStatusBar(provider: provider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _initialCenter,
                          initialZoom: 13,
                          minZoom: 5,
                          maxZoom: 18,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                          onTap: _onMapTap,
                        ),
                        children: [
                          buildBaseTileLayer(_baseMapStyle),
                          if (provider.result != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: provider.result!.points,
                                  strokeWidth: 5,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              // Only shelters are shown as destinations on
                              // this screen — no incidents/alerts here.
                              for (final shelter in provider.shelters)
                                Marker(
                                  point: LatLng(shelter.latitude, shelter.longitude),
                                  width: 40,
                                  height: 40,
                                  child: _ShelterMarker(
                                    shelter: shelter,
                                    isSelected: provider.destination != null &&
                                        provider.destination!.latitude == shelter.latitude &&
                                        provider.destination!.longitude == shelter.longitude,
                                    onTap: () => _onShelterTap(shelter),
                                  ),
                                ),
                              if (provider.origin != null)
                                Marker(
                                  point: provider.origin!,
                                  width: 32,
                                  height: 32,
                                  child: const _PointMarker(
                                    icon: Icons.my_location,
                                    color: Color(0xFF1E88E5),
                                  ),
                                ),
                            ],
                          ),
                          RichAttributionWidget(
                            alignment: AttributionAlignment.bottomLeft,
                            attributions: [
                              TextSourceAttribution(attributionFor(_baseMapStyle)),
                            ],
                          ),
                        ],
                      ),
                      if (provider.isLoadingShelters || provider.isLoading)
                        const Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (provider.error != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: _ErrorBanner(message: provider.error!),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(
                          children: [
                            MapLayerToggleButton(style: _baseMapStyle, onTap: _toggleBaseMapStyle),
                            const SizedBox(height: 12),
                            ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                            const SizedBox(height: 8),
                            ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (provider.result != null)
            RouteSummaryCard(result: provider.result!),
        ],
      ),
    );
  }
}

class _ShelterMarker extends StatelessWidget {
  final Shelter shelter;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShelterMarker({
    required this.shelter,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32);
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: shelter.name,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: const Icon(Icons.night_shelter, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _PointMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

class _ModeAndStatusBar extends StatelessWidget {
  final RouteProvider provider;
  const _ModeAndStatusBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SegmentedButton<TravelMode>(
            segments: const [
              ButtonSegment(
                value: TravelMode.walking,
                icon: Icon(Icons.directions_walk),
                label: Text('Walk'),
              ),
              ButtonSegment(
                value: TravelMode.driving,
                icon: Icon(Icons.directions_car),
                label: Text('Drive'),
              ),
            ],
            selected: {provider.mode},
            onSelectionChanged: (s) =>
                context.read<RouteProvider>().setMode(s.first),
          ),
          const Spacer(),
          Text(
            provider.origin == null
                ? 'Tap the map to set your start point'
                : provider.destination == null
                    ? 'Tap a shelter to route there'
                    : '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}