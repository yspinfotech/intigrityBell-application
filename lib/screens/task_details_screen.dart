import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../models/voice_note_model.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskModel task;
  TaskDetailsScreen({required this.task});

  @override
  _TaskDetailsScreenState createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late String _currentStatus;
  final AudioService _audioService = AudioService();
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.task.status;
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String? newStatus) async {
    if (newStatus == null || newStatus == _currentStatus) return;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final success = await taskProvider.updateTaskStatus(widget.task.id, newStatus);
    if (success) {
      setState(() => _currentStatus = newStatus);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status')));
    }
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

  Future<void> _uploadAppendedVoice() async {
    if (_recordedFilePath == null) return;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploading voice note...')));
    
    final success = await taskProvider.recordAndAddVoiceNote(widget.task.id, _recordedFilePath!);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice note appended!')));
      setState(() {
        _recordedFilePath = null;
      });
      // The task data in provider is updated, we could fetch it again to refresh UI
      taskProvider.fetchTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed')));
    }
  }

  void _playNote(VoiceNoteModel note) async {
    // Check if the URL is relative or absolute
    String url = note.audioUrl;
    if (url.startsWith('/uploads/')) {
       url = ApiService.baseUrl.replaceAll('/api', '') + url;
    }
    await _audioService.playAudio(url);
  }

  Widget _buildVoiceNoteList(List<VoiceNoteModel> notes) {
    if (notes.isEmpty) return Padding(padding: EdgeInsets.all(8), child: Text('No voice notes attached.'));
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Card(
          child: ListTile(
            leading: Icon(Icons.audiotrack),
            title: Text('Voice Note ${index + 1}'),
            subtitle: Text('By: ${note.uploadedBy.name} (${note.role})'),
            trailing: IconButton(
              icon: Icon(Icons.play_circle_fill, color: Colors.blue),
              onPressed: () => _playNote(note),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final isMember = user?.role == 'member';

    return Scaffold(
      appBar: AppBar(title: Text('Task Details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.task.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('From: ${widget.task.assignedByName ?? "System"}  |  To: ${widget.task.assignedToName ?? "Unassigned"}', style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 16),
            Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.task.description),
            SizedBox(height: 24),
            Row(
              children: [
                Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(width: 16),
                if (isMember)
                  DropdownButton<String>(
                    value: _currentStatus,
                    items: ['pending', 'working', 'completed']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                        .toList(),
                    onChanged: _updateStatus,
                  )
                else
                  Text(_currentStatus.toUpperCase(), style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
            Divider(height: 48),
            Text('Voice Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            _buildVoiceNoteList(widget.task.voiceNotes),
            
            // Member Appending section
            if (isMember && _currentStatus != 'completed') ...[
              Divider(height: 48),
              Text('Append Voice Note Response', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    iconSize: 48,
                    color: _audioService.isRecording ? Colors.red : Colors.blue,
                    icon: Icon(_audioService.isRecording ? Icons.stop_circle : Icons.mic),
                    onPressed: _toggleRecord,
                  ),
                  SizedBox(width: 16),
                  if (_recordedFilePath != null && !_audioService.isRecording) ...[
                    Expanded(child: Text('Recorded: ${_recordedFilePath!.split('/').last}')),
                    IconButton(
                      icon: Icon(Icons.upload, color: Colors.green),
                      onPressed: _uploadAppendedVoice,
                    )
                  ],
                  if (_audioService.isRecording)
                    Expanded(child: Text('Recording...', style: TextStyle(color: Colors.red))),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
