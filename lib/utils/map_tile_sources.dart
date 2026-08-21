import 'package:flutter_map/flutter_map.dart';

/// Which base map style is showing. Shared across every screen that uses
/// flutter_map, so toggling looks/behaves identically everywhere.
enum BaseMapStyle { street, topo }

/// Free, keyless raster tiles — no API key or billing setup required.
const String kStreetTileUrlTemplate =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
const List<String> kStreetTileSubdomains = ['a', 'b', 'c', 'd'];
const String kStreetAttribution = 'Map data: OpenStreetMap contributors | Tiles: CARTO';

/// OpenTopoMap — free, keyless raster tiles with real elevation-based
/// hypsometric shading (color intensity genuinely tied to height data)
/// and contour lines. Tiles stop at z17, hence maxNativeZoom below.
const String kTopoTileUrlTemplate = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
const List<String> kTopoTileSubdomains = ['a', 'b', 'c'];
const String kTopoAttribution =
    'Map data: OpenStreetMap contributors, SRTM | Map style: OpenTopoMap (CC-BY-SA)';

/// Builds the correct TileLayer for the given style. Use this instead of
/// constructing TileLayer directly, so every screen's base map stays in
/// sync if the tile source or attribution ever changes.
TileLayer buildBaseTileLayer(BaseMapStyle style) {
  if (style == BaseMapStyle.topo) {
    return TileLayer(
      urlTemplate: kTopoTileUrlTemplate,
      subdomains: kTopoTileSubdomains,
      userAgentPackageName: 'com.example.safezone',
      maxNativeZoom: 17,
    );
  }
  return TileLayer(
    urlTemplate: kStreetTileUrlTemplate,
    subdomains: kStreetTileSubdomains,
    userAgentPackageName: 'com.example.safezone',
  );
}

String attributionFor(BaseMapStyle style) =>
    style == BaseMapStyle.topo ? kTopoAttribution : kStreetAttribution;