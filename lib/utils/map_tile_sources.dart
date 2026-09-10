import 'package:flutter_map/flutter_map.dart';

enum BaseMapStyle { street, topo }

const String _cartoApiKeyRaw = String.fromEnvironment('CARTO_API_KEY');

/// CARTO now requires a free API key for raster basemap tiles.
/// Get one at https://carto.com/basemaps and pass it via
/// --dart-define-from-file=config/dev.json (see CARTO_API_KEY).
///
/// If no key is supplied at build time, falls back to a placeholder so the
/// app still compiles/runs — tiles will simply fail to load (401/403) until
/// a real key is provided.
const String _cartoPlaceholderKey = 'YOUR_CARTO_API_KEY_HERE';

String get _cartoApiKey =>
    _cartoApiKeyRaw.isEmpty ? _cartoPlaceholderKey : _cartoApiKeyRaw;

bool get isCartoApiKeyConfigured => _cartoApiKeyRaw.isNotEmpty;

String get kStreetTileUrlTemplate =>
  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?api_key=$_cartoApiKey';
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

  if (!isCartoApiKeyConfigured) {
    // ignore: avoid_print
    print(
      'Warning: CARTO_API_KEY is empty — using placeholder key. '
      'Street tiles will not load. Run with '
      '--dart-define-from-file=config/dev.json to supply a real key.',
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