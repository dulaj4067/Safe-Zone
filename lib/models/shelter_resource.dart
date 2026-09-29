/// Mirrors the `resource_type` Postgres enum. The database rejects any
/// other value, so these five are the complete set.
enum ResourceType {
  water,
  food,
  medicine,
  bedding,
  other;

  static ResourceType fromDb(String? value) => ResourceType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ResourceType.other,
      );

  String get label => switch (this) {
        ResourceType.water => 'Water',
        ResourceType.food => 'Food',
        ResourceType.medicine => 'Medicine',
        ResourceType.bedding => 'Bedding',
        ResourceType.other => 'Other supplies',
      };

  /// Pre-filled unit when adding a new supply of this type — matches the
  /// units the seed data already uses.
  String get defaultUnit => switch (this) {
        ResourceType.water => 'liters',
        ResourceType.food => 'meals',
        ResourceType.medicine => 'kits',
        ResourceType.bedding => 'mats',
        ResourceType.other => 'units',
      };
}

/// One row of `shelter_resources`: how much of one supply a shelter has.
class ShelterResource {
  final String id;
  final String shelterId;
  final ResourceType type;
  final double quantity;
  final String unit;
  final DateTime? updatedAt;

  ShelterResource({
    required this.id,
    required this.shelterId,
    required this.type,
    required this.quantity,
    required this.unit,
    this.updatedAt,
  });

  factory ShelterResource.fromMap(Map<String, dynamic> map) {
    return ShelterResource(
      id: map['id'] as String,
      shelterId: map['shelter_id'] as String,
      type: ResourceType.fromDb(map['resource_type'] as String?),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unit: (map['unit'] as String?) ?? 'units',
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  /// "500", "12.5" — whole numbers drop the trailing ".0".
  String get quantityText => quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString();

  /// "500 liters", "300 meal packs".
  String get quantityLabel => '$quantityText ${unit.replaceAll('_', ' ')}';
}
