import 'package:intl/intl.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String category;
  final String? voiceNotePath;
  final bool isAIGenerated;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.category = 'General',
    this.voiceNotePath,
    this.isAIGenerated = false,
  });

  String get dateString => DateFormat('MMM dd, yyyy').format(date);

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      category: json['category'] ?? 'General',
      voiceNotePath: json['voiceNotePath'],
      isAIGenerated: json['isAIGenerated'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'category': category,
      'voiceNotePath': voiceNotePath,
      'isAIGenerated': isAIGenerated,
    };
  }
}
