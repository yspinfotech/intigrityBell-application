import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'dart:convert';

class TaskProvider extends ChangeNotifier {
  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  
  List<TaskModel> get tasks => _tasks;
  bool get isLoading => _isLoading;
  
  List<TaskModel> get completedTasks => _tasks.where((t) => t.isCompleted).toList();
  List<TaskModel> get incompleteTasks => _tasks.where((t) => !t.isCompleted).toList();
  
  int get completedCount => completedTasks.length;
  int get missedCount => incompleteTasks.where((t) => t.scheduledDate.isBefore(DateTime.now())).length;
  
  double get productivityScore {
    if (_tasks.isEmpty) return 0;
    return (completedCount / _tasks.length) * 100;
  }

  Future<void> fetchTasks(String token, {String? currentUserId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/tasks', token: token);
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'];
          _tasks = data.map((item) => TaskModel.fromJson(item)).toList();
          
          // Re-schedule alarms cleanly for any unfinished tasks assigned to this user
          if (currentUserId != null) {
            for (var task in _tasks) {
              if (!task.isCompleted && task.assignedTo == currentUserId) {
                NotificationService().scheduleTaskReminders(task);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(TaskModel task, String token) async {
    try {
      final response = await ApiService.post(
        '/tasks', 
        {
          'title': task.title,
          'description': task.description,
          'assignedTo': task.assignedTo,
          'dueDate': task.scheduledDate.toIso8601String(),
          'priority': task.priority.toLowerCase(),
          'category': task.category,
          'voiceNote': task.voiceNote, // Changed from voiceNotePath
        },
        token: token
      );
      if (response.statusCode == 201) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final newTask = TaskModel.fromJson(body['data']);
          _tasks.add(newTask);
          
          // FIX 6-10: Schedule multiple task reminders
          NotificationService().scheduleTaskReminders(newTask);
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  Future<void> updateTask(TaskModel task, String token) async {
    try {
      final response = await ApiService.put(
        '/tasks/${task.id}',
        task.toJson(), // toJson already includes major fields, but let's check it
        token: token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          final updatedTask = TaskModel.fromJson(body['data']);
          final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
          if (index != -1) {
            _tasks[index] = updatedTask;
            
            // FIX 6-10: Update scheduled reminders
            NotificationService().scheduleTaskReminders(updatedTask);
            
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  Future<void> deleteTask(String taskId, String token) async {
    try {
      final response = await ApiService.delete('/tasks/$taskId', token: token);
      if (response.statusCode == 200) {
        _tasks.removeWhere((t) => t.id == taskId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> toggleTaskCompletion(String taskId, String token) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      final updatedStatus = !task.isCompleted ? 'completed' : 'pending';
      
      try {
        final response = await ApiService.put(
          '/tasks/$taskId',
          {'status': updatedStatus},
          token: token
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(response.body);
          if (body['success'] == true) {
            _tasks[index] = TaskModel.fromJson(body['data']);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Error toggling task: $e');
      }
    }
  }

  List<TaskModel> getTasksByDate(DateTime date) {
    return _tasks.where((t) =>
      t.scheduledDate.year == date.year &&
      t.scheduledDate.month == date.month &&
      t.scheduledDate.day == date.day
    ).toList();
  }

  List<TaskModel> getTodaysTasks() {
    final today = DateTime.now();
    return getTasksByDate(today);
  }

  /// Add task locally without backend (used when offline or no token)
  void addLocalTask(TaskModel task) {
    _tasks.add(task);
    notifyListeners();
  }
}

