import 'package:flutter_map/flutter_map.dart';

enum BaseMapStyle { street, topo }

const String _cartoApiKey = String.fromEnvironment('CARTO_API_KEY');

/// CARTO now requires a free API key for raster basemap tiles.
/// Get one at https://carto.com/basemaps and pass it via
/// --dart-define-from-file=config/dev.json (see CARTO_API_KEY).
String get kStreetTileUrlTemplate =>
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=$_cartoApiKey';
const List<String> kStreetTileSubdomains = ['a', 'b', 'c', 'd'];
const String kStreetAttribution = 'Map data: OpenStreetMap contributors | Tiles: CARTO';

const String kTopoTileUrlTemplate = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
const List<String> kTopoTileSubdomains = ['a', 'b', 'c'];
const String kTopoAttribution =
    'Map data: OpenStreetMap contributors, SRTM | Map style: OpenTopoMap (CC-BY-SA)';

TileLayer buildBaseTileLayer(BaseMapStyle style) {
  if (style == BaseMapStyle.topo) {
    return TileLayer(
      urlTemplate: kTopoTileUrlTemplate,
      subdomains: kTopoTileSubdomains,
      userAgentPackageName: 'com.example.safezone',
      maxNativeZoom: 17,
    );
  }
  assert(
    _cartoApiKey.isNotEmpty,
    'CARTO_API_KEY is empty — run with --dart-define-from-file=config/dev.json',
  );
  return TileLayer(
    urlTemplate: kStreetTileUrlTemplate,
    subdomains: kStreetTileSubdomains,
    userAgentPackageName: 'com.example.safezone',
  );
}

String attributionFor(BaseMapStyle style) =>
    style == BaseMapStyle.topo ? kTopoAttribution : kStreetAttribution;