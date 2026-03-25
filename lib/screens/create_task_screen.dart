import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../services/audio_service.dart';

class CreateTaskScreen extends StatefulWidget {
  @override
  _CreateTaskScreenState createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _assignedToController = TextEditingController(); // Hardcoded Object ID or mock dropdown
  
  final AudioService _audioService = AudioService();
  String? _recordedFilePath;

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_audioService.isRecording) {
      final path = await _audioService.stopRecording();
      setState(() {
        _recordedFilePath = path;
      });
    } else {
      await _audioService.startRecording();
      setState(() {});
    }
  }

  Future<void> _submitTask() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    // For test scope, if user is missing, fail. Assume assignedTo is an Admin ObjectId
    if (_titleController.text.isEmpty || _descController.text.isEmpty || _assignedToController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fill all fields and Assign To (ObjectID)')));
      return;
    }

    final success = await taskProvider.createTask(
      _titleController.text,
      _descController.text,
      _assignedToController.text, // "6524..."
      'pending',
      _recordedFilePath,
    );

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create task')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Task')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _assignedToController,
                decoration: InputDecoration(
                  labelText: 'Assign To User ID (e.g. from MongoDB seed)', 
                  border: OutlineInputBorder()
                ),
              ),
              SizedBox(height: 24),
              Text('Voice Note (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    iconSize: 48,
                    color: _audioService.isRecording ? Colors.red : Colors.blue,
                    icon: Icon(_audioService.isRecording ? Icons.stop_circle : Icons.mic),
                    onPressed: _toggleRecord,
                  ),
                  SizedBox(width: 16),
                  if (_recordedFilePath != null && !_audioService.isRecording)
                    Expanded(child: Text('Audio recorded: ${_recordedFilePath!.split('/').last}')),
                  if (_audioService.isRecording)
                    Expanded(child: Text('Recording in progress...', style: TextStyle(color: Colors.red))),
                ],
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submitTask,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text('Create & Assign Task'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
