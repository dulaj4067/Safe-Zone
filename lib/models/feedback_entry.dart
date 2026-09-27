/// One `feedback_forms` row: a citizen's 1–5 rating plus what they need.
class FeedbackEntry {
  final String id;
  final String? submittedBy;
  final String? zoneId;
  final String? needs;
  final int? rating;
  final DateTime createdAt;

  FeedbackEntry({
    required this.id,
    this.submittedBy,
    this.zoneId,
    this.needs,
    this.rating,
    required this.createdAt,
  });

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: map['id'] as String,
      submittedBy: map['submitted_by'] as String?,
      zoneId: map['zone_id'] as String?,
      needs: map['needs'] as String?,
      rating: (map['rating'] as num?)?.toInt(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}
