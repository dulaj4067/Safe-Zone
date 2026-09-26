class DisasterHistoryRecord {
  const DisasterHistoryRecord({
    required this.id,
    required this.zoneId,
    required this.disasterType,
    required this.date,
    required this.severity,
    required this.summary,
  });

  final String id;
  final String zoneId;
  final String disasterType;
  final DateTime date;
  final String severity;
  final String summary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneId': zoneId,
        'disasterType': disasterType,
        'date': date.toIso8601String(),
        'severity': severity,
        'summary': summary,
      };

  factory DisasterHistoryRecord.fromJson(Map<String, dynamic> json) =>
      DisasterHistoryRecord(
        id: json['id'] as String,
        zoneId: json['zoneId'] as String,
        disasterType: json['disasterType'] as String,
        date: DateTime.parse(json['date'] as String),
        severity: json['severity'] as String,
        summary: json['summary'] as String,
      );
}