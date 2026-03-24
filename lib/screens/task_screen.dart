import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import 'dart:math';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  void _showAddTaskModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTaskModal(),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      if (userProvider.token != null) {
        taskProvider.fetchTasks(userProvider.token!, currentUserId: userProvider.currentUser?.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final userProvider = Provider.of<UserProvider>(context);

    final isManager = userProvider.isManager;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isManager ? 'Tasks Management' : 'My Tasks',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          final tasks = taskProvider.tasks;
          
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                'No tasks yet',
                style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final TaskModel task = tasks[index];
              return TaskCard(task: task);
            },
          );
        },
      ),
      floatingActionButton: isManager ? FloatingActionButton(
        backgroundColor: const Color(0xFF2ECC71),
        onPressed: () => _showAddTaskModal(context),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ) : null,
    );
  }
}

class TaskCard extends StatefulWidget {
  final TaskModel task;

  const TaskCard({super.key, required this.task});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isExpanded = false; // Expanding logic
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  void _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.task.voiceNote == null) return;
      print("Voice note path: ${widget.task.voiceNote}");
      
      if (widget.task.voiceNote!.startsWith('data:audio')) {
        final base64String = widget.task.voiceNote!.split(',').last;
        final bytes = base64Decode(base64String);
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_voice_note_${widget.task.id}.m4a';
        await File(tempPath).writeAsBytes(bytes);
        await _audioPlayer.play(DeviceFileSource(tempPath));
      } else if (widget.task.voiceNote!.startsWith('http')) {
        await _audioPlayer.play(UrlSource(widget.task.voiceNote!));
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.task.voiceNote!));
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orangeAccent;
      case 'Low':
        return const Color(0xFF2ECC71);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isManager = userProvider.isManager;
    final token = userProvider.token ?? '';

    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddTaskModal(existingTask: widget.task),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    taskProvider.toggleTaskCompletion(widget.task.id, token);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    child: Icon(
                      widget.task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: widget.task.isCompleted ? const Color(0xFF2ECC71) : subtitleColor,
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.task.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (isManager)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => AddTaskModal(existingTask: widget.task),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0, top: 4.0),
                                child: Icon(Icons.edit, color: subtitleColor, size: 22),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (widget.task.description.isNotEmpty) ...[
                        Text(
                          widget.task.description,
                          maxLines: _isExpanded ? null : 2,
                          overflow: _isExpanded ? null : TextOverflow.ellipsis,
                          style: TextStyle(color: subtitleColor, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Voice Note Playback Full UI inside card
                      if (widget.task.voiceNote != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.only(left: 4, right: 12, top: 4, bottom: 4),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _togglePlayback,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2ECC71),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    activeTrackColor: const Color(0xFF2ECC71),
                                    inactiveTrackColor: isDarkMode ? Colors.white24 : Colors.black12,
                                    thumbColor: const Color(0xFF2ECC71),
                                  ),
                                  child: Slider(
                                    value: _position.inMilliseconds.toDouble(),
                                    max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                    onChanged: (value) {
                                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(_position.inSeconds > 0 ? _position : _duration),
                                style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: subtitleColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.task.dateString} - ${widget.task.timeString}',
                            style: TextStyle(color: subtitleColor, fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          if (widget.task.assignedTo != null) ...[
                            Icon(Icons.person_outline, color: subtitleColor, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'To: ${widget.task.assignedToName ?? widget.task.assignedTo ?? 'Unknown'}',
                                 style: TextStyle(color: subtitleColor, fontSize: 12),
                                 overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(widget.task.priority).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.task.priority,
                              style: TextStyle(
                                color: _getPriorityColor(widget.task.priority),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.task.categoryName ?? widget.task.category,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddTaskModal extends StatefulWidget {
  final TaskModel? existingTask;
  
  const AddTaskModal({super.key, this.existingTask});

  @override
  State<AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<AddTaskModal> with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  final List<String> _priorities = ['High', 'Medium', 'Low'];

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();

  bool _isRecording = false;
  String? _recordedFilePath;

  Timer? _recordTimer;
  int _recordDuration = 0;

  bool _isPreviewPlaying = false;
  Duration _previewDuration = Duration.zero;
  Duration _previewPosition = Duration.zero;

  // Animation for recording indicator
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPreviewPlaying = state == PlayerState.playing);
    });

    _previewPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _previewDuration = d);
    });

    _previewPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _previewPosition = p);
    });

    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPreviewPlaying = false;
          _previewPosition = _previewDuration;
        });
      }
    });

    if (widget.existingTask != null) {
      final task = widget.existingTask!;
      _titleController.text = task.title;
      _descController.text = task.description;
      _selectedAssignedToId = task.assignedTo;
      _selectedDate = task.scheduledDate;
      _selectedPriority = task.priority;
      _selectedCategoryId = task.category;
      _recordedFilePath = task.voiceNote;

      if (_recordedFilePath != null && !_recordedFilePath!.startsWith('data:')) {
        _previewPlayer.setSourceDeviceFile(_recordedFilePath!);
      }
    }

    // Fetch team members and categories for assignment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      if (userProvider.token != null) {
        userProvider.fetchUsers(userProvider.token!);
        categoryProvider.fetchCategories(userProvider.token!);
      }
    });
  }

  String? _selectedAssignedToId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _selectedPriority = 'Medium';

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _audioRecorder.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  void _presentDateTimePicker() async {
    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
        0, // Force ZERO seconds (CRITICAL)
      );
    });
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record voice notes', style: TextStyle(color: Colors.white))),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/task_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
      _recordedFilePath = null;
      _recordDuration = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordDuration++);
    });
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    _recordTimer?.cancel();
    
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
    });

    if (path != null) {
      await _previewPlayer.setSourceDeviceFile(path);
    }
  }

  Future<void> _togglePreviewPlayback() async {
    if (_isPreviewPlaying) {
      await _previewPlayer.pause();
    } else {
      if (_recordedFilePath != null) {
        if (_recordedFilePath!.startsWith('data:audio')) {
          final base64String = _recordedFilePath!.split(',').last;
          final bytes = base64Decode(base64String);
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/temp_preview_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await File(tempPath).writeAsBytes(bytes);
          await _previewPlayer.play(DeviceFileSource(tempPath));
        } else if (_recordedFilePath!.startsWith('http')) {
          await _previewPlayer.play(UrlSource(_recordedFilePath!));
        } else {
          if (_previewPosition == _previewDuration && _previewDuration > Duration.zero) {
            await _previewPlayer.seek(Duration.zero);
          }
          await _previewPlayer.play(DeviceFileSource(_recordedFilePath!));
        }
      }
    }
  }

  void _deleteRecording() {
    _previewPlayer.stop();
    setState(() {
      _recordedFilePath = null;
      _recordDuration = 0;
      _previewPosition = Duration.zero;
      _previewDuration = Duration.zero;
      _isPreviewPlaying = false;
    });
  }

  void _submitData() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Title is mandatory');
      return;
    }
    
    if (_selectedAssignedToId == null || _selectedAssignedToId!.isEmpty) {
      _showErrorSnackBar('Please select a user to assign the task to');
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      _showErrorSnackBar('Please select a category');
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final token = userProvider.token ?? '';

    String? finalVoiceNote = _recordedFilePath;
    if (_recordedFilePath != null && !_recordedFilePath!.startsWith('http') && !_recordedFilePath!.startsWith('data:')) {
      try {
        final bytes = await File(_recordedFilePath!).readAsBytes();
        final base64String = base64Encode(bytes);
        finalVoiceNote = 'data:audio/m4a;base64,$base64String';
      } catch (e) {
        print("Error encoding audio: $e");
      }
    }

    final newTask = TaskModel(
      id: widget.existingTask?.id ?? '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      createdDate: widget.existingTask?.createdDate ?? DateTime.now(),
      scheduledDate: _selectedDate,
      priority: _selectedPriority,
      category: _selectedCategoryId ?? '', // Should be the ID
      assignedBy: userProvider.currentUser?.id,
      assignedTo: _selectedAssignedToId,
      voiceNote: finalVoiceNote,
    );


    if (widget.existingTask != null) {
      taskProvider.updateTask(newTask, token);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task updated successfully'),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      taskProvider.addTask(newTask, token);
    }
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black45;
    final UIInputBg = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA);
    final UIBorder = isDarkMode ? Colors.white12 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 50,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.existingTask != null ? 'Edit Task' : 'Add New Task',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildInputField(
              controller: _titleController,
              hint: 'Enter task title',
              icon: Icons.title,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
            
            _buildInputField(
              controller: _descController,
              hint: 'Enter description',
              icon: Icons.description,
              maxLines: 3,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
            
            Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                final members = userProvider.teamMembers;
                return _buildDropdownField(
                  value: _selectedAssignedToId,
                  hint: 'Assign To (Optional)',
                  icon: Icons.person_add_alt_1,
                  items: members.map((u) => u.id).toList(), 
                  itemLabels: members.map((u) => u.name).toList(),
                  isDarkMode: isDarkMode,
                  onChanged: (val) {
                    setState(() => _selectedAssignedToId = val);
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, _) {
                final categories = categoryProvider.categories;
                return _buildDropdownField(
                  value: _selectedCategoryId,
                  hint: 'Category',
                  icon: Icons.category,
                  items: categories.map((c) => c.id).toList(),
                  itemLabels: categories.map((c) => c.name).toList(),
                  isDarkMode: isDarkMode,
                  onChanged: (val) {
                    setState(() => _selectedCategoryId = val);
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _presentDateTimePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: UIInputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: UIBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF2ECC71)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        DateFormat('MMM dd, yyyy - h:mm a').format(_selectedDate),
                        style: TextStyle(color: textColor, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.access_time, color: subtitleColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildDropdownField(
              value: _selectedPriority,
              hint: 'Priority',
              icon: Icons.flag,
              items: _priorities,
              isDarkMode: isDarkMode,
              onChanged: (val) {
                if (val != null) setState(() => _selectedPriority = val);
              },
            ),
            const SizedBox(height: 24),
            
            // Advance Voice Note Recorder UI
            Text('Voice Note', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UIInputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: UIBorder),
              ),
              child: _buildVoiceNoteUI(isDarkMode, textColor, subtitleColor),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitData,
                child: Text(
                  widget.existingTask != null ? 'Update Task' : 'Add Task',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceNoteUI(bool isDarkMode, Color textColor, Color subtitleColor) {
    if (_isRecording) {
      // Actively Recording View
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: _pulseController,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTimer(_recordDuration),
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              const Text('Recording...', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ],
          ),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop, color: Colors.redAccent, size: 28),
            ),
          ),
        ],
      );
    } else if (_recordedFilePath != null) {
      // Audio Recorded -> Preview Playback View
      return Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePreviewPlayback,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPreviewPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: const Color(0xFF2ECC71),
                        inactiveTrackColor: isDarkMode ? Colors.white24 : Colors.black12,
                        thumbColor: const Color(0xFF2ECC71),
                      ),
                      child: Slider(
                        value: _previewPosition.inMilliseconds.toDouble(),
                        max: _previewDuration.inMilliseconds > 0 ? _previewDuration.inMilliseconds.toDouble() : 1.0,
                        onChanged: (value) async {
                          final position = Duration(milliseconds: value.toInt());
                          await _previewPlayer.seek(position);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_previewPosition), style: TextStyle(color: subtitleColor, fontSize: 12)),
                          Text(_formatDuration(_previewDuration), style: TextStyle(color: subtitleColor, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _deleteRecording,
              ),
            ],
          ),
        ],
      );
    } else {
      // Idle / Start State
      return GestureDetector(
        onTap: _startRecording,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Color(0xFF2ECC71), size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              'Tap to record a voice note',
              style: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    required bool isDarkMode,
  }) {
    final bgColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA);
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;
    
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45),
        prefixIcon: Icon(icon, color: isDarkMode ? Colors.white54 : Colors.black45),
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2ECC71)),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    List<String>? itemLabels,
    required bool isDarkMode,
    required ValueChanged<String?> onChanged,
  }) {
    final bgColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA);
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

    // Safety check: ensure 'value' is actually in 'items'
    String? displayValue = value;
    if (value != null && !items.contains(value)) {
      displayValue = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: displayValue,
          isExpanded: true,
          dropdownColor: bgColor,
          icon: Icon(Icons.arrow_drop_down, color: isDarkMode ? Colors.white54 : Colors.black54),
          hint: Row(
            children: [
              Icon(icon, color: isDarkMode ? Colors.white54 : Colors.black45),
              const SizedBox(width: 16),
              Text(hint, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45)),
            ],
          ),
          items: List.generate(items.length, (index) {
            final itemValue = items[index];
            final itemLabel = itemLabels != null ? itemLabels[index] : itemValue;
            return DropdownMenuItem<String>(
              value: itemValue,
              child: Row(
                children: [
                  Icon(icon, color: isDarkMode ? Colors.white54 : Colors.black54),
                  const SizedBox(width: 16),
                  Text(itemLabel, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                ],
              ),
            );
          }),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
