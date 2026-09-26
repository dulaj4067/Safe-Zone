enum GuideCategory { flood, fire, earthquake, general }

class PreparednessGuide {
  const PreparednessGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.bodyContent,
    required this.coverImageUrl,
    required this.zoneTags,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
  });

  final String id;
  final String title;
  final GuideCategory category;
  final String bodyContent;
  final String coverImageUrl;
  final List<String> zoneTags;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  String get excerpt {
    final text = bodyContent.replaceAll(RegExp(r'[#*`>]'), '').trim();
    return text.length > 140 ? '${text.substring(0, 140)}...' : text;
  }

  PreparednessGuide copyWith({
    String? title,
    GuideCategory? category,
    String? bodyContent,
    String? coverImageUrl,
    List<String>? zoneTags,
    DateTime? updatedAt,
    bool? isArchived,
  }) =>
      PreparednessGuide(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        bodyContent: bodyContent ?? this.bodyContent,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        zoneTags: zoneTags ?? this.zoneTags,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isArchived: isArchived ?? this.isArchived,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'bodyContent': bodyContent,
        'coverImageUrl': coverImageUrl,
        'zoneTags': zoneTags,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isArchived': isArchived,
      };

  factory PreparednessGuide.fromJson(Map<String, dynamic> json) =>
      PreparednessGuide(
        id: json['id'] as String,
        title: json['title'] as String,
        category: GuideCategory.values.firstWhere(
          (value) => value.name == json['category'],
          orElse: () => GuideCategory.general,
        ),
        bodyContent: json['bodyContent'] as String? ?? '',
        coverImageUrl: json['coverImageUrl'] as String? ?? '',
        zoneTags: (json['zoneTags'] as List? ?? []).cast<String>(),
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isArchived: json['isArchived'] as bool? ?? false,
      );
}