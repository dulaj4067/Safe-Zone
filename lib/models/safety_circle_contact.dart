class SafetyCircleContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String relationship;

  /// Set when this contact's phone number matches a registered profile
  /// (resolved server-side, see sql/safety_circle_migration.sql). Null
  /// means the contact isn't an app user, so there's no location to show
  /// for them.
  final String? contactUserId;
  bool isSelected;

  SafetyCircleContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
    this.contactUserId,
    this.isSelected = false,
  });

  factory SafetyCircleContact.fromMap(Map<String, dynamic> map) {
    return SafetyCircleContact(
      id: map['id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String,
      relationship: map['relationship'] as String? ?? 'Contact',
      contactUserId: map['contact_user_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone_number': phoneNumber,
        'relationship': relationship,
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
