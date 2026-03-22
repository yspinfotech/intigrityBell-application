import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import 'dart:convert';

class CategoryProvider extends ChangeNotifier {
  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> fetchCategories(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/categories', token: token);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          _categories = data.map((e) => CategoryModel.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
