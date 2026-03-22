// lib/models/user_model.dart
class User {
  final String id;
  final String email;
  final String name;
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final DateTime createdAt;
  final String role; // 'admin', 'manager', 'team'
  String? profileImageUrl;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.createdAt,
    this.role = 'team',
    this.profileImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'notificationsEnabled': notificationsEnabled,
      'darkModeEnabled': darkModeEnabled,
      'createdAt': createdAt.toIso8601String(),
      'role': role,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      darkModeEnabled: json['darkModeEnabled'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      role: (json['role'] ?? 'team').toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }
}