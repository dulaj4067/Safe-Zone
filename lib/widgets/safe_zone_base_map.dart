import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utils/map_recenter.dart';
import '../utils/map_tile_config.dart';
import '../utils/map_tile_sources.dart';
import '../utils/sri_lanka_bounds.dart';
import 'map_controls.dart';

/// Shared FlutterMap chrome used by every full-screen map in the app (home,
/// incidents, the shelters/route screen): the base tile layer + attribution,
/// "jump to the user's position once a GPS fix arrives" behaviour, and the
/// My Location / base-style-toggle / zoom button stack. Each screen keeps
/// owning its own markers, overlays, and any map-specific interaction
/// (route tap-to-place, heatmap toggle, …) and hands them to this widget
/// instead of duplicating the FlutterMap/MapOptions/button boilerplate.
///
/// Each screen keeps its own [BaseMapStyle] choice — this widget does not
/// share it across screens. Toggling to topo on the Incidents map doesn't
/// change what the Shelters map shows; that's intentional, not an oversight.
class SafeZoneBaseMap extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;

  /// The device's current live position, if known. The map centers on it
  /// once, the first time it becomes non-null (like Google Maps on open),
  /// and it's what the My Location button recenters to.
  final LatLng? liveLocation;

  /// When this changes to a new non-null value, the map animates to it —
  /// used by the home screen's "resume where you left off" drift handling.
  final LatLng? resumeCenter;

  /// Pass an externally-owned controller when the caller also needs to
  /// drive the map itself (e.g. fitting the camera to a route's bounds).
  /// Leave null to let this widget create and dispose its own.
  final MapController? controller;

  /// Forwarded to [MapOptions.onTap] — used by the route screen to place
  /// origin/destination points by tapping the map.
  final void Function(TapPosition tapPosition, LatLng point)? onTap;

  /// Markers/circles/polylines layered on top of the base tiles, built by
  /// the caller from whatever data that screen already has. Rendered in
  /// order, below the attribution widget.
  final List<Widget> overlayLayers;

  /// Extra floating buttons stacked between the base-style toggle and the
  /// zoom buttons (e.g. the heatmap toggle on the home screen). Spacing
  /// before each one is added automatically.
  final List<Widget> extraControls;

  /// Floating buttons stacked above My Location, at the top of the control
  /// column (e.g. the home screen's SOS button). Spacing after each one is
  /// added automatically.
  final List<Widget> leadingControls;

  /// Optional content pinned to the top-left corner (a district label, a
  /// cached-tiles indicator, …).
  final Widget? topLeftOverlay;

  /// When set, the caller owns the street/terrain choice (e.g. inside its
  /// own layers menu) and the built-in style toggle button is hidden.
  final BaseMapStyle? baseMapStyle;

  const SafeZoneBaseMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 13,
    this.minZoom = kSriLankaMinZoom,
    this.maxZoom = 18,
    this.liveLocation,
    this.resumeCenter,
    this.controller,
    this.onTap,
    this.overlayLayers = const [],
    this.extraControls = const [],
    this.leadingControls = const [],
    this.topLeftOverlay,
    this.baseMapStyle,
  });

  @override
  State<SafeZoneBaseMap> createState() => _SafeZoneBaseMapState();
}

class _SafeZoneBaseMapState extends State<SafeZoneBaseMap> {
  late final MapController _mapController;
  late final bool _ownsController;
  BaseMapStyle _baseMapStyle = BaseMapStyle.street;

  /// The map opens on [SafeZoneBaseMap.initialCenter] until the first GPS
  /// fix arrives; once it does, jump to the user's position once (like
  /// Google Maps), then leave the camera alone so panning/zooming sticks.
  bool _centeredOnUser = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _mapController = widget.controller ?? MapController();
    // If a live fix is already known on the very first build (e.g. a fast
    // GPS lock before the first frame), start centered on it directly
    // rather than opening on initialCenter and only then animating over —
    // didUpdateWidget below only reacts to a *change*, so without this an
    // already-non-null liveLocation on the first build would never center.
    if (widget.liveLocation != null) _centeredOnUser = true;
  }

  @override
  void didUpdateWidget(SafeZoneBaseMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_centeredOnUser && widget.liveLocation != null) {
      _centeredOnUser = true;
      final live = widget.liveLocation!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final zoom = _mapController.camera.zoom;
        _mapController.move(live, zoom < 15 ? 15 : zoom);
      });
    }
    if (widget.resumeCenter != null &&
        widget.resumeCenter != oldWidget.resumeCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.resumeCenter!, _mapController.camera.zoom);
      });
    }
  }

  @override
  void dispose() {
    if (_ownsController) _mapController.dispose();
    super.dispose();
  }

  void _goToMyLocation() =>
      recenterOnUser(context, _mapController, widget.liveLocation);

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _toggleBaseMapStyle() {
    setState(() {
      _baseMapStyle = _baseMapStyle == BaseMapStyle.street
          ? BaseMapStyle.topo
          : BaseMapStyle.street;
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.baseMapStyle ?? _baseMapStyle;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.liveLocation ?? widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: widget.minZoom,
            maxZoom: widget.maxZoom,
            cameraConstraint: kSriLankaCameraConstraint,
            // Explicit: drag-to-pan, pinch-to-zoom, double-tap zoom,
            // two-finger rotate, and mouse-wheel/trackpad zoom on web/desktop.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: widget.onTap,
          ),
          children: [
            buildBaseTileLayer(style),
            ...widget.overlayLayers,
            // Required by OpenTopoMap's (and CartoDB's) usage policy. Shown
            // for both styles so it's always visible regardless of which
            // base layer is active.
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution(attributionFor(style))],
            ),
          ],
        ),
        if (widget.topLeftOverlay != null)
          Positioned(top: 12, left: 12, child: widget.topLeftOverlay!),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              for (final control in widget.leadingControls) ...[
                control,
                const SizedBox(height: 16),
              ],
              MyLocationButton(onTap: _goToMyLocation),
              if (widget.baseMapStyle == null) ...[
                const SizedBox(height: 8),
                MapLayerToggleButton(
                  style: _baseMapStyle,
                  onTap: _toggleBaseMapStyle,
                ),
              ],
              for (final control in widget.extraControls) ...[
                const SizedBox(height: 8),
                control,
              ],
              const SizedBox(height: 12),
              ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
              const SizedBox(height: 8),
              ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
            ],
          ),
        ),
      ],
    );
  }
}
