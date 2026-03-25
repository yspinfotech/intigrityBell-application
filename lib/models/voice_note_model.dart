import 'user_model.dart';

class VoiceNoteModel {
  final String audioUrl;
  final UserModel uploadedBy;
  final String role; // "manager" or "member"
  final DateTime createdAt;

  VoiceNoteModel({
    required this.audioUrl,
    required this.uploadedBy,
    required this.role,
    required this.createdAt,
  });

  factory VoiceNoteModel.fromJson(Map<String, dynamic> json) {
    return VoiceNoteModel(
      audioUrl: json['audioUrl'] ?? '',
      uploadedBy: UserModel.fromJson(json['uploadedBy'] ?? {}),
      role: json['role'] ?? 'member',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioUrl': audioUrl,
      'uploadedBy': uploadedBy.toJson(),
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
