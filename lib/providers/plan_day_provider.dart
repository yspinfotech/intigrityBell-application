import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/plan_day_model.dart';

class PlanDayProvider extends ChangeNotifier {
  List<PlanDayModel> _plans = [];
  bool _isLoading = false;
  static const String _storageKey = 'daily_plans_storage';

  List<PlanDayModel> get plans => _plans;
  bool get isLoading => _isLoading;

  PlanDayProvider() {
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        _plans = jsonList.map((e) => PlanDayModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _savePlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_plans.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving plans: $e');
    }
  }

  List<PlanDayModel> getPlansByDate(DateTime date) {
    return _plans.where((p) => 
      p.date.year == date.year &&
      p.date.month == date.month &&
      p.date.day == date.day
    ).toList();
  }

  void addPlan(PlanDayModel plan) {
    _plans.add(plan);
    _savePlans();
    notifyListeners();
  }

  void updatePlan(PlanDayModel plan) {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index != -1) {
      _plans[index] = plan;
      _savePlans();
      notifyListeners();
    }
  }

  void togglePlanStatus(String id) {
    final index = _plans.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plans[index] = _plans[index].copyWith(isCompleted: !_plans[index].isCompleted);
      _savePlans();
      notifyListeners();
    }
  }

  void deletePlan(String id) {
    _plans.removeWhere((p) => p.id == id);
    _savePlans();
    notifyListeners();
  }
}
