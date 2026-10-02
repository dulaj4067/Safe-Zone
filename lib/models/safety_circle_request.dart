/// An incoming "X wants to add you to their safety circle" request — one
/// row from the `my_pending_safety_circle_requests` view (see
/// sql/safety_circle_migration.sql). Shown to [ownerName]'s target contact
/// so they can confirm or decline before their live location becomes
/// visible to that circle.
class SafetyCircleRequest {
  final String id;
  final String ownerId;
  final String ownerName;
  final String relationship;

  SafetyCircleRequest({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.relationship,
  });

  factory SafetyCircleRequest.fromMap(Map<String, dynamic> map) {
    return SafetyCircleRequest(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      ownerName: map['owner_name'] as String? ?? 'Someone',
      relationship: map['relationship'] as String? ?? 'Contact',
    );
  }
}
