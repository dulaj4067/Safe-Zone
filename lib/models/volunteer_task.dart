/// Mirrors the `volunteer_task_status` Postgres enum.
enum VolunteerTaskStatus {
  open,
  inProgress,
  completed,
  cancelled;

  static VolunteerTaskStatus fromDb(String? value) => switch (value) {
        'in_progress' => VolunteerTaskStatus.inProgress,
        'completed' => VolunteerTaskStatus.completed,
        'cancelled' => VolunteerTaskStatus.cancelled,
        _ => VolunteerTaskStatus.open,
      };

  String get dbValue => switch (this) {
        VolunteerTaskStatus.open => 'open',
        VolunteerTaskStatus.inProgress => 'in_progress',
        VolunteerTaskStatus.completed => 'completed',
        VolunteerTaskStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        VolunteerTaskStatus.open => 'Open',
        VolunteerTaskStatus.inProgress => 'In progress',
        VolunteerTaskStatus.completed => 'Completed',
        VolunteerTaskStatus.cancelled => 'Cancelled',
      };
}

/// A `volunteer_tasks` row plus the ids of everyone signed up to it
/// (embedded from `volunteer_assignments`).
class VolunteerTask {
  final String id;
  final String title;
  final String? description;
  final String? zoneId;
  final String? shelterId;
  final int volunteersNeeded;
  final VolunteerTaskStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final List<String> volunteerIds;

  VolunteerTask({
    required this.id,
    required this.title,
    this.description,
    this.zoneId,
    this.shelterId,
    required this.volunteersNeeded,
    required this.status,
    this.createdBy,
    required this.createdAt,
    this.volunteerIds = const [],
  });

  factory VolunteerTask.fromMap(Map<String, dynamic> map) {
    final assignments = (map['volunteer_assignments'] as List?) ?? const [];
    return VolunteerTask(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      zoneId: map['zone_id'] as String?,
      shelterId: map['shelter_id'] as String?,
      volunteersNeeded: (map['volunteers_needed'] as num?)?.toInt() ?? 1,
      status: VolunteerTaskStatus.fromDb(map['status'] as String?),
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      volunteerIds: assignments
          .map((a) => (a as Map<String, dynamic>)['volunteer_id'] as String)
          .toList(),
    );
  }

  int get signedUpCount => volunteerIds.length;
  bool get isFull => signedUpCount >= volunteersNeeded;
  bool isSignedUp(String? userId) =>
      userId != null && volunteerIds.contains(userId);
}
