import 'user_model.dart';

class VoiceNoteModel {
  final String type; // "voice" or "text"
  final String? text;
  final String? audioUrl;
  final UserModel uploadedBy;
  final String role; // "manager", "member", "team"
  final DateTime createdAt;

  VoiceNoteModel({
    required this.type,
    this.text,
    this.audioUrl,
    required this.uploadedBy,
    required this.role,
    required this.createdAt,
  });

  bool get isVoice => type == 'voice';
  bool get isText => type == 'text';

  factory VoiceNoteModel.fromJson(Map<String, dynamic> json) {
    String? uploaderId;
    UserModel? userModel;
    if (json['uploadedBy'] is Map<String, dynamic>) {
       userModel = UserModel.fromJson(json['uploadedBy']);
       uploaderId = userModel.id;
    } else if (json['uploadedBy'] != null) {
       uploaderId = json['uploadedBy'].toString();
       userModel = UserModel(
         id: uploaderId,
         name: 'Unknown',
         email: '',
         role: json['role'] ?? 'member',
         token: '',
       );
    } else {
       userModel = UserModel(
         id: '',
         name: 'Unknown',
         email: '',
         role: 'member',
         token: '',
       );
    }

    return VoiceNoteModel(
      type: json['type'] ?? 'voice',
      text: json['text'],
      audioUrl: json['audioUrl'],
      uploadedBy: userModel,
      role: json['role'] ?? 'member',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'audioUrl': audioUrl,
      'uploadedBy': uploadedBy.toJson(),
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
