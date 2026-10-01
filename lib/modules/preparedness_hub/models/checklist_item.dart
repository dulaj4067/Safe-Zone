class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.riskFactorTags,
    this.isDone = false,
  });

  final String id;
  final String title;
  final String description;
  final List<String> riskFactorTags;
  final bool isDone;

  ChecklistItem copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? riskFactorTags,
    bool? isDone,
  }) => ChecklistItem(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    riskFactorTags: riskFactorTags ?? this.riskFactorTags,
    isDone: isDone ?? this.isDone,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'riskFactorTags': riskFactorTags,
    'isDone': isDone,
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id:
        json['id'] as String? ??
        'checklist-${DateTime.now().microsecondsSinceEpoch}',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    riskFactorTags: (json['riskFactorTags'] as List? ?? []).cast<String>(),
    isDone: json['isDone'] as bool? ?? false,
  );
}
