import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  List<User> _allUsers = [];
  String? _token;

  User? get currentUser => _currentUser;
  List<User> get allUsers => _allUsers;
  List<User> get teamMembers => _allUsers.where((u) => u.role == 'team').toList();
  String? get token => _token;

  bool get isLoggedIn => _currentUser != null;

  bool get isManager => _currentUser?.role == 'manager' || _currentUser?.role == 'admin';
  bool get isAdmin => _currentUser?.role == 'admin';

  Future<bool> login(String email, String password) async {
    try {
      final response = await ApiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['token'];
        _currentUser = User.fromJson(data);
        ApiService.setToken(_token);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', jsonEncode(data));

        await fetchUsers(_token!);
        notifyListeners();
        return true;
      } else {
        throw data['message'] ?? 'Login failed';
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<void> fetchUsers(String token) async {
    try {
      final response = await ApiService.get('/users', token: token);
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          _allUsers = data.map((item) => User.fromJson(item)).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('token')) return;

    _token = prefs.getString('token');
    final userData = jsonDecode(prefs.getString('user')!);
    _currentUser = User.fromJson(userData);
    ApiService.setToken(_token);
    
    await fetchUsers(_token!);
    notifyListeners();
  }

  void loginUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void updateProfileImage(String imageUrl) {
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        notificationsEnabled: _currentUser!.notificationsEnabled,
        darkModeEnabled: _currentUser!.darkModeEnabled,
        createdAt: _currentUser!.createdAt,
        role: _currentUser!.role,
        profileImageUrl: imageUrl,
      );
      notifyListeners();
    }
  }

  void toggleNotifications() {
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        notificationsEnabled: !_currentUser!.notificationsEnabled,
        darkModeEnabled: _currentUser!.darkModeEnabled,
        createdAt: _currentUser!.createdAt,
        role: _currentUser!.role,
        profileImageUrl: _currentUser!.profileImageUrl,
      );
      notifyListeners();
    }
  }

  void updateNotificationSettings(bool enabled) {
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        notificationsEnabled: enabled,
        darkModeEnabled: _currentUser!.darkModeEnabled,
        createdAt: _currentUser!.createdAt,
        role: _currentUser!.role,
        profileImageUrl: _currentUser!.profileImageUrl,
      );
      notifyListeners();
    }
  }

  void updateDarkMode(bool enabled) {
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        notificationsEnabled: _currentUser!.notificationsEnabled,
        darkModeEnabled: enabled,
        createdAt: _currentUser!.createdAt,
        role: _currentUser!.role,
        profileImageUrl: _currentUser!.profileImageUrl,
      );
      notifyListeners();
    }
  }

  void logoutUser() {
    logout();
  }
}