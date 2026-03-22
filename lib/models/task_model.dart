import 'package:intl/intl.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final DateTime createdDate;
  final DateTime scheduledDate;
  final bool isCompleted;
  final String priority; // Low, Medium, High
  final String category; // Currently ID or name
  final String? categoryName;
  final String? assignedBy;
  final String? assignedByEmail;
  final String? assignedByName;
  final String? assignedTo;
  final String? assignedToName;
  final String status; // 'pending', 'in-progress', 'completed'
  final String? voiceNotePath;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdDate,
    required this.scheduledDate,
    this.isCompleted = false,
    this.priority = 'Medium',
    this.category = 'General',
    this.categoryName,
    this.assignedBy,
    this.assignedByEmail,
    this.assignedByName,
    this.assignedTo,
    this.assignedToName,
    this.status = 'pending',
    this.voiceNotePath,
  });

  String get dateString => DateFormat('MMM dd, yyyy').format(scheduledDate);
  String get timeString => DateFormat('h:mm a').format(scheduledDate);

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    String? catName;
    String? catId;
    if (json['category'] is Map) {
      catId = (json['category']['_id'] ?? '').toString();
      catName = (json['category']['name'] ?? 'General').toString();
    } else {
      catId = (json['category'] ?? 'General').toString();
      catName = catId;
    }

    return TaskModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdDate: DateTime.parse(json['createdDate'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      scheduledDate: DateTime.parse(json['scheduledDate'] ?? json['dueDate'] ?? DateTime.now().toIso8601String()),
      isCompleted: (json['isCompleted'] == true || (json['status']?.toString().toLowerCase() == 'completed')),
      priority: (json['priority'] ?? 'medium').toString(),
      category: catId,
      categoryName: catName,
      assignedBy: (json['assignedBy'] is Map) ? (json['assignedBy']['_id'] ?? '').toString() : json['assignedBy']?.toString(),
      assignedByName: (json['assignedBy'] is Map) ? (json['assignedBy']['name'] ?? '').toString() : null,
      assignedByEmail: (json['assignedBy'] is Map) ? (json['assignedBy']['email'] ?? '').toString() : null,
      assignedTo: (json['assignedTo'] is Map) ? (json['assignedTo']['_id'] ?? '').toString() : json['assignedTo']?.toString(),
      assignedToName: (json['assignedTo'] is Map) ? (json['assignedTo']['name'] ?? '').toString() : null,
      status: (json['status'] ?? (json['isCompleted'] == true ? 'completed' : 'pending')).toString(),
      voiceNotePath: json['voiceNotePath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'dueDate': scheduledDate.toIso8601String(),
      'priority': priority.toLowerCase(),
      'category': category, // Correct field name
      'assignedTo': assignedTo,
      'status': status,
    };
  }
}
