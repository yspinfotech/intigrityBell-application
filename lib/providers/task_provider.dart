import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskProvider with ChangeNotifier {
  List<TaskModel> _tasks = [];
  bool _isLoading = false;

  List<TaskModel> get tasks => _tasks;
  bool get isLoading => _isLoading;

  // Legacy Getters expected by other screens
  List<TaskModel> get incompleteTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<TaskModel> get completedTasks => _tasks.where((t) => t.isCompleted).toList();
  int get missedCount => 0; // Stub
  int get completedCount => completedTasks.length;
  double get productivityScore => _tasks.isEmpty ? 0.0 : (completedTasks.length / _tasks.length) * 100.0;

  // Legacy Methods
  List<TaskModel> getTasksByDate(DateTime date) => _tasks;
  List<TaskModel> getTodaysTasks() => _tasks;
  Future<void> toggleTaskCompletion(String id, String token) async {
    await updateTaskStatus(id, 'completed');
  }
  Future<void> updateTask(TaskModel task, String token) async {}
  Future<void> addTask(TaskModel task, String token) async {
    // Filter out null audioUrls and convert to List<String>
    final audioPaths = task.voiceNotes
        .where((v) => v.isVoice && v.audioUrl != null)
        .map((v) => v.audioUrl!)
        .toList();
    await createTask(task.title, task.description, task.assignedTo ?? '', task.status, audioPaths);
  }
  void addLocalTask(TaskModel task) {}

  // Fetch Methods
  Future<void> fetchTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/tasks');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('tasks')) {
          data = decoded['tasks'] as List<dynamic>;
        } else if (decoded is Map && decoded.containsKey('data')) {
          data = decoded['data'] as List<dynamic>;
        } else {
          data = [];
        }
        _tasks = data.map((json) => TaskModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('❌ fetchTasks exception: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createTask(String title, String description, String assignedTo, String? status, List<String> audioPaths) async {
    try {
      final body = {
        'title': title,
        'description': description,
        'assignedTo': assignedTo,
        'status': status ?? 'pending',
      };
      final response = await ApiService.post('/tasks', body);
      if (response.statusCode == 201) {
        final newTask = json.decode(response.body);
        final taskId = newTask['_id'] ?? newTask['id'];
        if (audioPaths.isNotEmpty) {
           await addVoiceNotes(taskId, audioPaths);
        } else {
           await fetchTasks();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
    }
    return false;
  }

  Future<bool> updateTaskStatus(String taskId, String status) async {
    try {
      final response = await ApiService.put('/tasks/$taskId/status', {'status': status});
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final taskData = body.containsKey('data') ? body['data'] : body;
        final updatedTask = TaskModel.fromJson(taskData);
        
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          _tasks[index] = updatedTask;
          notifyListeners();
        } else {
          await fetchTasks();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
    return false;
  }

  Future<bool> addVoiceNotes(String taskId, List<String> audioPaths) async {
    try {
      debugPrint('🎙️ addVoiceNotes: taskId=$taskId files=${audioPaths.length}');
      final response = await ApiService.postMultipart(
        '/tasks/$taskId/voice',
        {},
        filePaths: audioPaths,
        fileField: 'voiceNotes',
      );
      
      final bodyText = await response.stream.bytesToString();
      debugPrint('🎙️ addVoiceNotes: status=${response.statusCode} body=$bodyText');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(bodyText);
        final taskData = body.containsKey('data') ? body['data'] : body;
        final updatedTask = TaskModel.fromJson(taskData);
        
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          _tasks[index] = updatedTask;
          notifyListeners();
        } else {
          await fetchTasks();
        }
        return true;
      } else {
        debugPrint('❌ addVoiceNotes: server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ addVoiceNotes exception: $e');
    }
    return false;
  }

  Future<bool> addChatMessage(String taskId, String text) async {
    try {
      final response = await ApiService.post('/tasks/$taskId/message', {'text': text});
      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final taskData = body.containsKey('data') ? body['data'] : body;
        final updatedTask = TaskModel.fromJson(taskData);
        
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          _tasks[index] = updatedTask;
          notifyListeners();
        } else {
          await fetchTasks();
        }
        return true;
      }
    } catch (e) {
      debugPrint('❌ addChatMessage exception: $e');
    }
    return false;
  }

  Future<bool> deleteVoiceNote(String taskId, String voiceId) async {
    try {
      debugPrint('🗑️ deleteVoiceNote: taskId=$taskId voiceId=$voiceId');
      final response = await ApiService.delete('/tasks/$taskId/voice/$voiceId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final taskData = body.containsKey('data') ? body['data'] : body;
        final updatedTask = TaskModel.fromJson(taskData);
        
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          _tasks[index] = updatedTask;
          notifyListeners();
        } else {
          await fetchTasks();
        }
        return true;
      } else {
        final body = response.body;
        debugPrint('❌ deleteVoiceNote: server returned ${response.statusCode} - $body');
      }
    } catch (e) {
      debugPrint('❌ deleteVoiceNote exception: $e');
    }
    return false;
  }
}
