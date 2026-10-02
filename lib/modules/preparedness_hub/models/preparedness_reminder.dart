enum ReminderRecurrence { none, monthly, seasonal }

extension ReminderRecurrenceLabel on ReminderRecurrence {
  String get label {
    switch (this) {
      case ReminderRecurrence.none:
        return 'One-time';
      case ReminderRecurrence.monthly:
        return 'Monthly';
      case ReminderRecurrence.seasonal:
        return 'Seasonal';
    }
  }
}

class PreparednessReminder {
  const PreparednessReminder({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledDate,
    required this.recurrence,
    required this.zoneTags,
  });

  final String id;
  final String title;
  final String message;
  final DateTime scheduledDate;
  final ReminderRecurrence recurrence;
  final List<String> zoneTags;

  PreparednessReminder copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? scheduledDate,
    ReminderRecurrence? recurrence,
    List<String>? zoneTags,
  }) => PreparednessReminder(
    id: id ?? this.id,
    title: title ?? this.title,
    message: message ?? this.message,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    recurrence: recurrence ?? this.recurrence,
    zoneTags: zoneTags ?? this.zoneTags,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'scheduledDate': scheduledDate.toIso8601String(),
    'recurrence': recurrence.name,
    'zoneTags': zoneTags,
  };

  factory PreparednessReminder.fromJson(Map<String, dynamic> json) =>
      PreparednessReminder(
        id:
            json['id'] as String? ??
            'reminder-${DateTime.now().microsecondsSinceEpoch}',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        scheduledDate:
            DateTime.tryParse(json['scheduledDate'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 7)),
        recurrence: ReminderRecurrence.values.firstWhere(
          (value) => value.name == json['recurrence'],
          orElse: () => ReminderRecurrence.none,
        ),
        zoneTags: (json['zoneTags'] as List? ?? []).cast<String>(),
      );
}
