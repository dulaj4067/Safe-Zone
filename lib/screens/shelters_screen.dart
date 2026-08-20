import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/route_provider.dart';
import '../models/route_result.dart';
import '../services/routing_service.dart';
import '../widgets/route_summary_card.dart';

/// Combines Story 5 (request a route between two points) and Story 6
/// (display the suggested route on a map) into one screen — they're the
/// same interaction from a citizen's point of view: tap two points, see
/// the path. Splitting them into separate screens would add a navigation
/// step for no benefit during an actual disaster.
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
  GoogleMapController? _mapController;

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
          _ModeAndStatusBar(provider: provider),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(7.4167, 81.8206),
                    zoom: 12,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  onTap: (latLng) {
                    context.read<RouteProvider>().setPointFromTap(latLng);
                    if (context.read<RouteProvider>().canRequestRoute) {
                      _requestAndFit(context);
                    }
                  },
                  markers: _buildMarkers(provider),
                  polylines: provider.result != null
                      ? {
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: provider.result!.points,
                            width: 5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        }
                      : {},
                ),
                if (provider.isLoading)
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
              ],
            ),
          ),
          if (provider.result != null)
            RouteSummaryCard(result: provider.result!),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(RouteProvider provider) {
    final markers = <Marker>{};
    if (provider.origin != null) {
      markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: provider.origin!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ));
    }
    if (provider.destination != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: provider.destination!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }
    return markers;
  }

  Future<void> _requestAndFit(BuildContext context) async {
    final provider = context.read<RouteProvider>();
    await provider.requestRoute();
    final result = provider.result;
    if (result != null && _mapController != null) {
      // Story 6 AC: map auto-fits to show the entire route.
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(result.bounds, 60),
      );
    }
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
                    ? 'Tap the map to set your destination'
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
