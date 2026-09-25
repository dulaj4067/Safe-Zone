enum BaseMapStyle { street, topo }

const String kCartoApiKeyRaw = String.fromEnvironment('CARTO_API_KEY');
const String kCartoPlaceholderKey = 'YOUR_CARTO_API_KEY_HERE';

String get cartoApiKey =>
    kCartoApiKeyRaw.isEmpty ? kCartoPlaceholderKey : kCartoApiKeyRaw;

bool get isCartoApiKeyConfigured => kCartoApiKeyRaw.isNotEmpty;

String get kStreetTileUrlTemplate =>
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?api_key=$cartoApiKey';
const List<String> kStreetTileSubdomains = ['a', 'b', 'c', 'd'];
const String kStreetAttribution =
    'Map data: OpenStreetMap contributors | Tiles: CARTO';

const String kTopoTileUrlTemplate =
    'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
const List<String> kTopoTileSubdomains = ['a', 'b', 'c'];
const String kTopoAttribution =
    'Map data: OpenStreetMap contributors, SRTM | Map style: OpenTopoMap (CC-BY-SA)';
