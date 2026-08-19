class Zone {
  final String id;
  final String name;
  final String? region;
  final double? centroidLat;
  final double? centroidLng;

  Zone({
    required this.id,
    required this.name,
    this.region,
    this.centroidLat,
    this.centroidLng,
  });

  factory Zone.fromMap(Map<String, dynamic> map) {
    final geo = map['centroid'];
    return Zone(
      id: map['id'] as String,
      name: map['name'] as String,
      region: map['region'] as String?,
      centroidLat: (geo?['coordinates']?[1] as num?)?.toDouble(),
      centroidLng: (geo?['coordinates']?[0] as num?)?.toDouble(),
    );
  }
}
