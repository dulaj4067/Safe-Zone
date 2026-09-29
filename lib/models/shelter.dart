/// A designated safe shelter location, mapped to the `shelters` table.
///
/// Columns read: id, name, type, location (PostGIS point), capacity,
/// occupancy, status, managed_by, contact_phone, updated_at. The table has
/// no address column, so [address] stays null unless one is ever added.
class Shelter {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int? capacity;
  final String? address;

  /// `shelter`, `relief_camp` or `medical_point`.
  final String? type;

  /// `open`, `full` or `closed`.
  final String? status;

  /// People currently sheltered.
  final int? occupancy;

  /// Emergency desk phone number.
  final String? contactPhone;

  /// Profile id of the person / organisation that runs the shelter.
  final String? managedBy;
  final DateTime? updatedAt;

  Shelter({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.capacity,
    this.address,
    this.type,
    this.status,
    this.occupancy,
    this.contactPhone,
    this.managedBy,
    this.updatedAt,
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
      type: map['type'] as String?,
      status: map['status'] as String?,
      occupancy: (map['occupancy'] as num?)?.toInt(),
      contactPhone: map['contact_phone'] as String?,
      managedBy: map['managed_by'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  /// Human-readable kind, e.g. "Relief Camp".
  String get typeLabel {
    switch (type) {
      case 'relief_camp':
        return 'Relief Camp';
      case 'medical_point':
        return 'Medical Point';
      case 'shelter':
        return 'Shelter';
      default:
        return type == null || type!.isEmpty
            ? 'Shelter'
            : type![0].toUpperCase() + type!.substring(1).replaceAll('_', ' ');
    }
  }

  /// Share of capacity in use (0–1), or null if either number is unknown.
  double? get occupancyFraction {
    final cap = capacity;
    final occ = occupancy;
    if (cap == null || cap <= 0 || occ == null) return null;
    return (occ / cap).clamp(0.0, 1.0);
  }
}
