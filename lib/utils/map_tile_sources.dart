import 'package:flutter_map/flutter_map.dart';

import '../services/tile_cache_service.dart';
import 'map_tile_config.dart';

final TileCacheService safeZoneTileCache = TileCacheService();

TileLayer buildBaseTileLayer(BaseMapStyle style) {
  if (style == BaseMapStyle.topo) {
    return TileLayer(
      urlTemplate: kTopoTileUrlTemplate,
      subdomains: kTopoTileSubdomains,
      userAgentPackageName: 'com.example.safezone',
      maxNativeZoom: 17,
      tileProvider: NetworkTileProvider(
        httpClient: safeZoneTileCache.createHttpClient(),
        silenceExceptions: true,
      ),
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
    tileProvider: NetworkTileProvider(
      httpClient: safeZoneTileCache.createHttpClient(),
      silenceExceptions: true,
    ),
  );
}

String attributionFor(BaseMapStyle style) =>
    style == BaseMapStyle.topo ? kTopoAttribution : kStreetAttribution;