import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/map_tile_config.dart';

const Duration kTileStalePeriod = Duration(days: 14);
const int kMaxCachedTiles = 2000;

class TileCacheEntry {
  final String key;
  final DateTime lastAccessed;

  const TileCacheEntry({required this.key, required this.lastAccessed});
}

/// Small, deterministic LRU policy kept separate from the file cache so it is
/// easy to test without a platform cache or network.
class TileCachePolicy {
  final int maxEntries;
  final Duration stalePeriod;

  const TileCachePolicy({
    this.maxEntries = kMaxCachedTiles,
    this.stalePeriod = kTileStalePeriod,
  });

  List<TileCacheEntry> evict(
    Iterable<TileCacheEntry> entries, {
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(stalePeriod);
    final retained = entries
        .where((entry) => entry.lastAccessed.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    return retained.take(maxEntries).toList(growable: false);
  }
}

class CachedTileHttpClient extends http.BaseClient {
  final http.Client _inner;
  final CacheManager _cacheManager;
  final TileCacheService _service;

  CachedTileHttpClient(this._service, {CacheManager? cacheManager})
      : _inner = http.Client(),
        _cacheManager = cacheManager ?? SafeZoneTileCacheManager.instance;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key = request.url.toString();
    try {
      final cached = await _cacheManager.getFileFromCache(key);
      if (cached != null && cached.validTill.isAfter(DateTime.now())) {
        final bytes = await cached.file.readAsBytes();
        return _streamedResponse(bytes, request, 200, cached.validTill);
      }

      final response = await _inner.send(request);
      final bytes = await response.stream.toBytes();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _cacheManager.putFile(key, bytes, fileExtension: 'png');
      }
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      final stale = await _cacheManager.getFileFromCache(key);
      if (stale == null) rethrow;
      final bytes = await stale.file.readAsBytes();
      _service.markCachedTileShown();
      return _streamedResponse(bytes, request, 200, stale.validTill);
    }
  }

  http.StreamedResponse _streamedResponse(
    Uint8List bytes,
    http.BaseRequest request,
    int statusCode,
    DateTime validTill,
  ) {
    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      contentLength: bytes.length,
      request: request,
      headers: const {'content-type': 'image/png'},
      reasonPhrase: validTill.isBefore(DateTime.now()) ? 'stale-cache' : null,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class SafeZoneTileCacheManager {
  static final CacheManager instance = CacheManager(
    Config(
      'safezone_tiles',
      stalePeriod: kTileStalePeriod,
      maxNrOfCacheObjects: kMaxCachedTiles,
    ),
  );
}

class TileCacheService {
  TileCacheService({CacheManager? cacheManager})
      : _cacheManager = cacheManager ?? SafeZoneTileCacheManager.instance;

  final CacheManager _cacheManager;
  final ValueNotifier<bool> showingCachedTiles = ValueNotifier(false);
  final ValueNotifier<bool> offline = ValueNotifier(false);

  void markCachedTileShown() {
    showingCachedTiles.value = true;
  }

  CachedTileHttpClient createHttpClient() =>
      CachedTileHttpClient(this, cacheManager: _cacheManager);

  Future<void> prefetchRoute(
    LatLngBounds bounds, {
    BaseMapStyle style = BaseMapStyle.street,
    double bufferKilometres = 2,
    int minZoom = 12,
    int maxZoom = 15,
  }) async {
    final expanded = _expandBounds(bounds, bufferKilometres);
    final urls = <String>{};
    for (var zoom = minZoom; zoom <= maxZoom; zoom++) {
      final minX = _tileX(expanded.west, zoom);
      final maxX = _tileX(expanded.east, zoom);
      final minY = _tileY(expanded.north, zoom);
      final maxY = _tileY(expanded.south, zoom);
      for (var x = minX; x <= maxX; x++) {
        for (var y = minY; y <= maxY; y++) {
          urls.add(tileUrl(style, zoom, x, y));
        }
      }
    }

    for (final url in urls) {
      try {
        await _cacheManager.getSingleFile(url, key: url);
      } catch (_) {
        // Prefetch is best effort. The route and map remain usable if a tile
        // server is unavailable while the user is preparing to travel.
      }
    }
  }

  String tileUrl(BaseMapStyle style, int z, int x, int y) {
    final template = style == BaseMapStyle.topo
        ? kTopoTileUrlTemplate
        : kStreetTileUrlTemplate;
    final subdomains = style == BaseMapStyle.topo
        ? kTopoTileSubdomains
        : kStreetTileSubdomains;
    return template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y')
        .replaceAll('{s}', subdomains[(x + y) % subdomains.length]);
  }

  LatLngBounds _expandBounds(LatLngBounds bounds, double kilometres) {
    final latBuffer = kilometres / 111.0;
    final midpoint = (bounds.north + bounds.south) / 2;
    final longitudeScale = math.max(0.2, math.cos(midpoint * math.pi / 180));
    final lngBuffer = kilometres / (111.0 * longitudeScale);
    return LatLngBounds(
      LatLng(bounds.south - latBuffer, bounds.west - lngBuffer),
      LatLng(bounds.north + latBuffer, bounds.east + lngBuffer),
    );
  }

  int _tileX(double longitude, int zoom) {
    final normalized = (longitude + 180) / 360;
    return (normalized * (1 << zoom)).floor().clamp(0, (1 << zoom) - 1);
  }

  int _tileY(double latitude, int zoom) {
    final radians = latitude.clamp(-85.0511, 85.0511) * math.pi / 180;
    final normalized =
        (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) / 2;
    return (normalized * (1 << zoom)).floor().clamp(0, (1 << zoom) - 1);
  }
}
