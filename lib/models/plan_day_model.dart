class PlanDayModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final bool isCompleted;
  final String? voiceNotePath;

  PlanDayModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.isCompleted = false,
    this.voiceNotePath,
  });

  PlanDayModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? isCompleted,
    String? voiceNotePath,
  }) {
    return PlanDayModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
    );
  }

  factory PlanDayModel.fromJson(Map<String, dynamic> json) {
    return PlanDayModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      isCompleted: json['isCompleted'] ?? false,
      voiceNotePath: json['voiceNotePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'isCompleted': isCompleted,
      'voiceNotePath': voiceNotePath,
    };
  }
}
