import 'user_model.dart';
import 'voice_note_model.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String? assignedBy;
  final String? assignedTo;
  final String? assignedByNameField;
  final String? assignedToNameField;
  final String status; // "pending", "working", "completed"
  final List<VoiceNoteModel> voiceNotes;
  final DateTime createdAt;

  // Legacy Getters to support the old UI code without breaking
  bool get isCompleted => status == 'completed';
  DateTime get scheduledDate => createdAt;
  DateTime get createdDate => createdAt;
  String? get voiceNote => voiceNotes.isNotEmpty ? voiceNotes.first.audioUrl : null;
  String get dateString => "${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}";
  String get timeString => "${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}";
  String? get assignedToName => assignedToNameField ?? assignedTo;
  String? get assignedByName => assignedByNameField ?? assignedBy;
  String get priority => 'medium';
  String get category => 'General';
  String? get categoryName => null;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    this.assignedBy,
    this.assignedTo,
    this.assignedByNameField,
    this.assignedToNameField,
    this.status = 'pending',
    this.voiceNotes = const [],
    DateTime? createdAt,
    DateTime? createdDate,
    DateTime? scheduledDate,
    String? priority,
    String? category,
    String? voiceNote,
  }) : createdAt = createdAt ?? createdDate ?? DateTime.now();

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    var voiceNotesList = json['voiceNotes'] as List? ?? [];
    List<VoiceNoteModel> voiceNotes = voiceNotesList.map((i) => VoiceNoteModel.fromJson(i)).toList();
    
    String? assignedToId;
    String? assignedToNm;
    if (json['assignedTo'] is Map) {
      assignedToId = json['assignedTo']['_id'] ?? json['assignedTo']['id'];
      assignedToNm = json['assignedTo']['name']?.toString();
    } else {
      assignedToId = json['assignedTo']?.toString();
    }
    
    String? assignedById;
    String? assignedByNm;
    if (json['assignedBy'] is Map) {
      assignedById = json['assignedBy']['_id'] ?? json['assignedBy']['id'];
      assignedByNm = json['assignedBy']['name']?.toString();
    } else {
      assignedById = json['assignedBy']?.toString();
    }

    return TaskModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      assignedBy: assignedById,
      assignedTo: assignedToId,
      assignedByNameField: assignedByNm,
      assignedToNameField: assignedToNm,
      status: json['status'] ?? 'pending',
      voiceNotes: voiceNotes,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'assignedBy': assignedBy,
      'assignedTo': assignedTo,
      'status': status,
      'voiceNotes': voiceNotes.map((v) => v.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
