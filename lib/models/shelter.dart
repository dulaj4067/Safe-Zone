/// Where a shelter is in the submit → verify → approve/reject workflow.
/// Only [approved] shelters appear on the public Shelters page.
enum ShelterApproval {
  pending,
  approved,
  rejected;

  static ShelterApproval fromDb(String? value) => switch (value) {
        'pending' => ShelterApproval.pending,
        'rejected' => ShelterApproval.rejected,
        _ => ShelterApproval.approved,
      };

  String get label => switch (this) {
        ShelterApproval.pending => 'Awaiting review',
        ShelterApproval.approved => 'Approved',
        ShelterApproval.rejected => 'Rejected',
      };
}

/// A designated safe shelter location, mapped to the `shelters` table.
///
/// Columns read: id, name, type, location (PostGIS point), capacity,
/// occupancy, status, managed_by, contact_phone, updated_at, plus the
/// approval workflow fields added by
/// sql/shelter_workflow_and_volunteer_fixes_migration.sql. Rows from a
/// database without that migration read as approved.
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

  /// Free-text notes from whoever runs the shelter (facilities, access).
  final String? description;

  final ShelterApproval approval;

  /// Who submitted the shelter for review.
  final String? submittedBy;

  /// Why an authority rejected the submission, shown to the submitter.
  final String? rejectionReason;

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
    this.description,
    this.approval = ShelterApproval.approved,
    this.submittedBy,
    this.rejectionReason,
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
      description: map['description'] as String?,
      approval: ShelterApproval.fromDb(map['approval_status'] as String?),
      submittedBy: map['submitted_by'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
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
