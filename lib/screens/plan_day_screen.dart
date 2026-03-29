import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/plan_day_provider.dart';
import '../models/plan_day_model.dart';
import 'package:intl/intl.dart';

class PlanDayScreen extends StatefulWidget {
  final DateTime? initialDate;
  const PlanDayScreen({super.key, this.initialDate});

  @override
  _PlanDayScreenState createState() => _PlanDayScreenState();
}

class _PlanDayScreenState extends State<PlanDayScreen> {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentRecordingPath;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'record_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentRecordingPath = '${directory.path}/$fileName';

        const config = RecordConfig();
        await _audioRecorder.start(config, path: _currentRecordingPath!);

        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _currentRecordingPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _playVoiceNote(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('Error playing voice note: $e');
    }
  }

  void _showAddPlanModal() {
    _titleController.clear();
    _descriptionController.clear();
    _currentRecordingPath = null;
    _selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'New Daily Plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'What are you planning?',
                  hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add some details...',
                  hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (_isRecording) {
                        final path = await _audioRecorder.stop();
                        setModalState(() {
                          _isRecording = false;
                          _currentRecordingPath = path;
                        });
                        setState(() { _isRecording = false; _currentRecordingPath = path; });
                      } else {
                        if (await _audioRecorder.hasPermission()) {
                          final directory = await getApplicationDocumentsDirectory();
                          final fileName = 'record_${DateTime.now().millisecondsSinceEpoch}.m4a';
                          final path = '${directory.path}/$fileName';
                          await _audioRecorder.start(const RecordConfig(), path: path);
                          setModalState(() {
                            _isRecording = true;
                            _currentRecordingPath = null;
                          });
                          setState(() { _isRecording = true; });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_currentRecordingPath != null)
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.green),
                      onPressed: () => _playVoiceNote(_currentRecordingPath!),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      if (_titleController.text.isNotEmpty) {
                        final plan = PlanDayModel(
                          id: const Uuid().v4(),
                          title: _titleController.text,
                          description: _descriptionController.text,
                          date: _selectedDate,
                          voiceNotePath: _currentRecordingPath,
                        );
                        context.read<PlanDayProvider>().addPlan(plan);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Plan'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text('My Daily Plans', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: Theme.of(context).iconTheme.color),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlanModal,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
      body: Consumer<PlanDayProvider>(
        builder: (context, provider, _) {
          final plans = provider.getPlansByDate(_selectedDate);
          
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'No plans for ${DateFormat('MMM dd').format(_selectedDate)}',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: plan.isCompleted,
                      onChanged: (_) => provider.togglePlanStatus(plan.id),
                      activeColor: Theme.of(context).primaryColor,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                              plan.title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 16,
                                decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          if (plan.description.isNotEmpty)
                            Text(
                              plan.description,
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    if (plan.voiceNotePath != null)
                      IconButton(
                        icon: Icon(Icons.play_circle_fill, color: Theme.of(context).primaryColor),
                        onPressed: () => _playVoiceNote(plan.voiceNotePath!),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => provider.deletePlan(plan.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
