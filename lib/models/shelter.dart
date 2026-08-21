/// A designated safe shelter location.
///
/// TODO: field names/geography-column name here are a best guess following
/// the same pattern as Zone.fromMap ('centroid') and DisasterAlert.fromMap
/// ('center_point') — adjust `map['location']` and the field list below to
/// match your actual `shelters` table schema in Supabase.
class Shelter {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int? capacity;
  final String? address;

  Shelter({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.capacity,
    this.address,
  });

  factory Shelter.fromMap(Map<String, dynamic> map) {
    final geo = map['location'];
    final lat = (geo?['coordinates']?[1] as num?)?.toDouble() ??
        (map['latitude'] as num?)?.toDouble() ??
        0.0;
    final lng = (geo?['coordinates']?[0] as num?)?.toDouble() ??
        (map['longitude'] as num?)?.toDouble() ??
        0.0;

    return Shelter(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: lat,
      longitude: lng,
      capacity: (map['capacity'] as num?)?.toInt(),
      address: map['address'] as String?,
    );
  }
}