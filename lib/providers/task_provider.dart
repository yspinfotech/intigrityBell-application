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

  // Legacy Methods expected by other screens
  List<TaskModel> getTasksByDate(DateTime date) => _tasks;
  List<TaskModel> getTodaysTasks() => _tasks;
  Future<void> toggleTaskCompletion(String id, String token) async {
    await updateTaskStatus(id, 'completed');
  }
  Future<void> updateTask(TaskModel task, String token) async {}
  Future<void> addTask(TaskModel task, String token) async {
    await createTask(task.title, task.description, task.assignedTo ?? '', task.status, task.voiceNote);
  }
  void addLocalTask(TaskModel task) {}

  // Current and Legacy Fetch Method
  Future<void> fetchTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/tasks');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _tasks = data.map((json) => TaskModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createTask(String title, String description, String assignedTo, String? status, String? initialAudioPath) async {
    try {
      String? uploadedUrl;
      if (initialAudioPath != null && initialAudioPath.isNotEmpty) {
        uploadedUrl = await uploadAudioFile(initialAudioPath);
      }
      final body = {
        'title': title,
        'description': description,
        'assignedTo': assignedTo,
        'status': status ?? 'pending',
      };
      final response = await ApiService.post('/tasks', body);
      if (response.statusCode == 201) {
        final newTask = json.decode(response.body);
        final taskId = newTask['_id'];
        if (uploadedUrl != null) {
           await addVoiceNote(taskId, uploadedUrl);
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
        await fetchTasks();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
    return false;
  }

  Future<String?> uploadAudioFile(String filePath) async {
     try {
        final response = await ApiService.postMultipart('/upload', {}, filePath: filePath, fileField: 'audio');
        if (response.statusCode == 200) {
           final responseData = await response.stream.bytesToString();
           final decoded = json.decode(responseData);
           return decoded['url'];
        }
     } catch (e) {
        debugPrint('Upload audio error: $e');
     }
     return null;
  }

  Future<bool> recordAndAddVoiceNote(String taskId, String localAudioPath) async {
    try {
      String? audioUrl = await uploadAudioFile(localAudioPath);
      if (audioUrl != null) {
         return await addVoiceNote(taskId, audioUrl);
      }
    } catch(e) {
      debugPrint('Error in recording flow: $e');
    }
    return false;
  }

  Future<bool> addVoiceNote(String taskId, String audioUrl) async {
    try {
      final response = await ApiService.post('/tasks/$taskId/voice', {'audioUrl': audioUrl});
      if (response.statusCode == 201) {
        await fetchTasks();
        return true;
      }
    } catch (e) {
      debugPrint('Error adding voice note: $e');
    }
    return false;
  }
}

