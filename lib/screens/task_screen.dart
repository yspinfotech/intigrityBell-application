import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../providers/category_provider.dart';
import '../services/api_service.dart';
import 'task_details_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {

  @override
  void initState() {
    super.initState();
    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.token != null) {
        Provider.of<TaskProvider>(context, listen: false).fetchTasks();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;


    final userProvider = Provider.of<UserProvider>(context);
    final isManager = userProvider.isManager;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Tasks',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,

      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          // Show spinner while loading
          if (taskProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }

          if (taskProvider.tasks.isEmpty) {
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.24),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks yet',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.54),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Provider.of<TaskProvider>(
                        context,
                        listen: false,
                      ).fetchTasks();
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: Theme.of(context).primaryColor,
                    ),
                    label: Text(
                      'Refresh',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildTaskList(taskProvider.tasks, taskProvider);
        },
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              backgroundColor: Theme.of(context).primaryColor,
              onPressed: () => _showAddTaskModal(context),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks, TaskProvider taskProvider) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks found in this category',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) => TaskCard(
        task: tasks[index],
      ),
    );
  }

  void _showAddTaskModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTaskModal(),
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
  bool _isExpanded = false; // Expanding logic

  Color _getPriorityColor(String priority, BuildContext context) {
    switch (priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orangeAccent;
      case 'Low':
        return Theme.of(context).primaryColor;
      default:
        return Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.4) ??
            Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isManager = userProvider.isManager;

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final token = userProvider.token ?? '';

    final cardColor = Theme.of(context).cardColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.54) ??
        Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium!.color!.withOpacity(0.05),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskDetailsScreen(task: widget.task),
              ),
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
                      widget.task.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: widget.task.isCompleted
                          ? Theme.of(context).primaryColor
                          : subtitleColor,
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.task.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: widget.task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (isManager)
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      AddTaskModal(existingTask: widget.task),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 16.0,
                                  bottom: 8.0,
                                  top: 4.0,
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: subtitleColor,
                                  size: 22,
                                ),
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

                      // Voice Note Indicator (Tells them to click to listen)
                      if (widget.task.voiceNotes.any((n) => n.isVoice))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.mic,
                                  size: 16,
                                  color: Theme.of(context).primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                'Voice note included (Tap to listen)',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: subtitleColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.task.dateString} - ${widget.task.timeString}',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.task.assignedTo?.toString() != null) ...[
                            Icon(
                              Icons.person_outline,
                              color: subtitleColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.task.assignedToName ?? "Member",
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(
                                widget.task.priority,
                                context,
                              ).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.task.priority,
                              style: TextStyle(
                                color: _getPriorityColor(
                                  widget.task.priority,
                                  context,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.color!.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.task.status,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
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

class _AddTaskModalState extends State<AddTaskModal>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final List<String> _priorities = ['High', 'Medium', 'Low'];
  final List<String> _statuses = ['pending', 'working', 'completed'];

  // Voice Note Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  final List<String> _tempVoiceNotes = [];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!.title;
      _descController.text = widget.existingTask!.description;
      _selectedPriority = widget.existingTask!.priority;
      _selectedStatus = widget.existingTask!.status;
      _selectedAssignedToId = widget.existingTask!.assignedTo;
      _selectedDate = widget.existingTask!.createdAt;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Fetch team members and categories for assignment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      if (userProvider.token != null) {
        userProvider.fetchUsers(userProvider.token!);
        categoryProvider.fetchCategories(userProvider.token!);
      }
    });
  }

  String? _selectedAssignedToId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String _selectedPriority = 'Medium';
  String _selectedStatus = 'pending';

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _presentDateTimePicker() async {
    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
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
      );
    });
  }

  // Voice Recording Methods
  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone permission is required to record voice notes',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/task_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
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
      if (path != null) {
        _tempVoiceNotes.add(path);
      }
    });
  }

  void _deleteTempVoiceNote(int index) {
    setState(() {
      _tempVoiceNotes.removeAt(index);
    });
  }

  void _saveTask() async {
    if (_titleController.text.isEmpty) {
      _showErrorSnackBar('Title is mandatory');
      return;
    }

    if (_selectedAssignedToId == null || _selectedAssignedToId!.isEmpty) {
      _showErrorSnackBar('Please select a user to assign the task to');
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token ?? '';

    final newTask = TaskModel(
      id: widget.existingTask?.id ?? '',
      title: _titleController.text,
      description: _descController.text,
      assignedTo: _selectedAssignedToId,
      status: _selectedStatus,
      createdAt: _selectedDate,
    );

    if (widget.existingTask != null) {
      await taskProvider.updateTask(newTask, token);
      if (_tempVoiceNotes.isNotEmpty) {
        await taskProvider.addVoiceNotes(
          widget.existingTask!.id,
          _tempVoiceNotes,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task updated successfully'),
            backgroundColor: Theme.of(context).primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      await taskProvider.createTask(
        newTask.title,
        newTask.description,
        newTask.assignedTo ?? '',
        newTask.status,
        _tempVoiceNotes,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  String _formatTimer(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).cardColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.45) ??
        Colors.grey;
    final UIInputBg = Theme.of(context).scaffoldBackgroundColor;
    final UIBorder =
        Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.12) ??
        Colors.black12;
    final isManager = Provider.of<UserProvider>(
      context,
      listen: false,
    ).isManager;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: UIBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.existingTask == null ? 'Create Task' : 'Edit Task',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            if (isManager || widget.existingTask == null) ...[
              _buildInputField(
                controller: _titleController,
                hint: 'Task Title',
                icon: Icons.title,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 16),

              _buildInputField(
                controller: _descController,
                hint: 'Enter description',
                icon: Icons.description_outlined,
                maxLines: 3,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 16),

              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  final members = userProvider.teamMembers;
                  return _buildDropdown(
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

              _buildDropdown(
                value: _selectedPriority,
                hint: 'Priority',
                icon: Icons.priority_high,
                items: _priorities,
                isDarkMode: isDarkMode,
                onChanged: (val) {
                  setState(() => _selectedPriority = val!);
                },
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _presentDateTimePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: UIInputBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          DateFormat(
                            'MMM dd, yyyy - h:mm a',
                          ).format(_selectedDate),
                          style: TextStyle(color: textColor, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                widget.existingTask!.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.existingTask!.description,
                style: TextStyle(color: subtitleColor, fontSize: 15),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                value: _selectedStatus,
                hint: 'Update Status',
                icon: Icons.sync,
                items: _statuses,
                isDarkMode: isDarkMode,
                onChanged: (val) {
                  setState(() => _selectedStatus = val!);
                },
              ),
            ],
            const SizedBox(height: 24),

            // Advance Voice Note Recorder UI
            Text(
              'Voice Note',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UIInputBg,
                borderRadius: BorderRadius.circular(20),
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
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _saveTask,
                child: const Text(
                  'Confirm & Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceNoteUI(
    bool isDarkMode,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.existingTask != null &&
            widget.existingTask!.voiceNotes.isNotEmpty) ...[
          const Text(
            'Previous Voice Notes:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (var note in widget.existingTask!.voiceNotes)
            if (note.isVoice)
              VoicePlayerWidget(
                audioPath: note.audioUrl ?? '',
                label:
                    '${note.role[0].toUpperCase()}${note.role.substring(1)}: ${note.uploadedBy.name}',
                isLocal: false,
              ),
          const Divider(),
        ],
        if (_tempVoiceNotes.isNotEmpty) ...[
          const Text(
            'Unsaved Voice Notes:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _tempVoiceNotes.length; i++)
            Row(
              children: [
                Expanded(
                  child: VoicePlayerWidget(
                    audioPath: _tempVoiceNotes[i],
                    isLocal: true,
                    label: 'New Recording ${i + 1}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteTempVoiceNote(i),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
        if (_isRecording)
          Row(
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recording...',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
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
                  child: const Icon(
                    Icons.stop,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                ),
              ),
            ],
          )
        else
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Hold to add a voice note',
                  style: TextStyle(
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    required bool isDarkMode,
  }) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withOpacity(0.4),
        ),
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
        ),
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    List<String>? itemLabels,
    required bool isDarkMode,
    required void Function(String?) onChanged,
  }) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final displayValue = (value != null && items.contains(value)) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: displayValue,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
          ),
          hint: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
              ),
              const SizedBox(width: 16),
              Text(
                hint,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.4),
                ),
              ),
            ],
          ),
          items: List.generate(items.length, (index) {
            final itemValue = items[index];
            final itemLabel = itemLabels != null ? itemLabels[index] : itemValue;
            return DropdownMenuItem<String>(
              value: itemValue,
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    itemLabel,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
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

class VoicePlayerWidget extends StatefulWidget {
  final String audioPath;
  final bool isLocal;
  final String? label;

  const VoicePlayerWidget({
    super.key,
    required this.audioPath,
    this.isLocal = false,
    this.label,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      Source source;
      if (widget.isLocal) {
        source = DeviceFileSource(widget.audioPath);
      } else {
        // Resolve URL
        String url = widget.audioPath;
        if (!url.startsWith('http')) {
          const baseUrl = "http://192.168.1.16:8000";
          url = url.startsWith('/') ? "$baseUrl$url" : "$baseUrl/$url";
        }
        source = UrlSource(url);
      }
      await _player.play(source);
    }
  }

  String _format(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Theme.of(context).primaryColor,
                        ),
                        child: Slider(
                          value: _position.inMilliseconds.toDouble(),
                          max: _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (val) =>
                              _player.seek(Duration(milliseconds: val.toInt())),
                        ),
                      ),
                    ),
                    Text(
                      _format(_position.inSeconds > 0 ? _position : _duration),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
