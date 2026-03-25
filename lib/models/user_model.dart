class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // "manager" or "member"
  final String token;
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final DateTime? createdAt;
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.token = '',
    this.notificationsEnabled = true,
    this.darkModeEnabled = false,
    this.createdAt,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'member',
      token: json['token'] ?? '',
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      darkModeEnabled: json['darkModeEnabled'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : DateTime.now(),
      profileImageUrl: json['profileImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id, // fallback
      'name': name,
      'email': email,
      'role': role,
      'token': token,
      'notificationsEnabled': notificationsEnabled,
      'darkModeEnabled': darkModeEnabled,
      'createdAt': createdAt?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
    };
  }
}

typedef User = UserModel;