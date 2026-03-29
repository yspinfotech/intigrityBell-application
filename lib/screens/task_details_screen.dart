import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/task_model.dart';
import '../models/voice_note_model.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../services/api_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskModel task;
  const TaskDetailsScreen({super.key, required this.task});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _chatController = TextEditingController();
  bool _isRecording = false;
  bool _isUploading = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  List<String> _pendingVoiceNotes = [];
  String? _currentStatus; 

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.task.status;
  }

  @override
  void dispose() {
    _chatController.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String? newStatus) async {
    if (newStatus == null || newStatus == _currentStatus) return;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final success = await taskProvider.updateTaskStatus(widget.task.id, newStatus);
    if (success) {
      if (mounted) setState(() => _currentStatus = newStatus);
      _showSnack('Status updated! ✅', Colors.green);
    } else {
      _showSnack('Failed to update status', Colors.red);
    }
  }

  Future<void> _startRecording() async {
    debugPrint('🎙️ _startRecording requested');
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint('❌ Microphone permission denied');
      _showSnack('Microphone permission required', Colors.red);
      return;
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/reply_${DateTime.now().millisecondsSinceEpoch}.m4a';
      debugPrint('🎙️ Starting recorder at $path');
      await _recorder.start(const RecordConfig(), path: path);
      
      _recordDuration = 0;
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDuration++);
      });
      
      if (mounted) setState(() => _isRecording = true);
      debugPrint('🎙️ Recorder started successfully');
    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      _showSnack('Failed to start recording', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    debugPrint('🎙️ _stopRecording requested');
    try {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      debugPrint('🎙️ Recorder stopped. Path: $path');
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          if (path != null) {
            _pendingVoiceNotes.add(path);
            debugPrint('🎙️ Added to pending: ${_pendingVoiceNotes.length} files');
          } else {
            debugPrint('⚠️ Recording stopped but path was null');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _sendText() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isUploading) return;

    debugPrint('💬 _sendText: "$text"');
    setState(() => _isUploading = true);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final success = await taskProvider.addChatMessage(widget.task.id, text);
    
    if (mounted) {
      setState(() {
        _isUploading = false;
        if (success) {
          debugPrint('✅ Text sent successfully');
          _chatController.clear();
        } else {
          debugPrint('❌ Failed to send text');
          _showSnack('Failed to send message', Colors.red);
        }
      });
    }
  }

  Future<void> _sendVoiceNotes(String taskId) async {
    if (_pendingVoiceNotes.isEmpty || _isUploading) return;
    
    debugPrint('🎙️ _sendVoiceNotes: ${_pendingVoiceNotes.length} files');
    setState(() => _isUploading = true);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    final success = await taskProvider.addVoiceNotes(taskId, List.from(_pendingVoiceNotes));
    
    if (mounted) {
      setState(() {
        _isUploading = false;
        if (success) {
          debugPrint('✅ Voice notes uploaded successfully');
          _pendingVoiceNotes.clear();
          _showSnack('Voice notes sent! 🎙️', Colors.green);
        } else {
          debugPrint('❌ Voice note upload failed');
          _showSnack('Upload failed. Check server.', Colors.red);
        }
      });
    }
  }

  void _removePending(int index) => setState(() => _pendingVoiceNotes.removeAt(index));

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatTimer(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Color _statusColor(String s) {
    switch (s) {
      case 'working': return Colors.orangeAccent;
      case 'completed': return Theme.of(context).primaryColor;
      default: return Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) ?? Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey;
    final border = Theme.of(context).dividerColor;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
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
        title: Text('Task Details',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          final task = taskProvider.tasks.firstWhere(
            (t) => t.id == widget.task.id, 
            orElse: () => widget.task
          );
          
          _currentStatus ??= task.status;

          final currentUser = userProvider.currentUser;
          final isAssigned = task.assignedTo == currentUser?.id;
          final canSeeConvo = isManager || isAssigned;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Task Info Card ──────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(task.title,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _statusColor(task.status).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(task.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _statusColor(task.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      )),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 14, color: subtitleColor),
                                const SizedBox(width: 4),
                                Text('From: ${task.assignedByName ?? "System"}',
                                    style: TextStyle(color: subtitleColor, fontSize: 13)),
                                const SizedBox(width: 16),
                                Icon(Icons.assignment_ind_outlined, size: 14, color: subtitleColor),
                                const SizedBox(width: 4),
                                Text('To: ${task.assignedToName ?? "Member"}',
                                    style: TextStyle(color: subtitleColor, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text('Description',
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(task.description,
                                style: TextStyle(color: textColor, fontSize: 15, height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Status Update Bar ───────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, color: _statusColor(task.status)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Update Status',
                                  style: TextStyle(
                                      color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _currentStatus,
                              underline: const SizedBox(),
                              dropdownColor: cardColor,
                              items: ['pending', 'working', 'completed']
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s[0].toUpperCase() + s.substring(1),
                                            style: TextStyle(
                                                color: _statusColor(s),
                                                fontWeight: FontWeight.bold)),
                                      ))
                                  .toList(),
                              onChanged: isManager || isAssigned ? _updateStatus : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Conversation List ──────────────────────────
                      if (canSeeConvo) ...[
                        Row(
                          children: [
                            Icon(Icons.forum_outlined, color: subtitleColor, size: 18),
                            const SizedBox(width: 8),
                            Text('Conversation',
                                style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (task.voiceNotes.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text('No messages yet', style: TextStyle(color: subtitleColor)),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: task.voiceNotes.length,
                            itemBuilder: (context, i) {
                              final note = task.voiceNotes[i];
                              final isMe = note.uploadedBy.id == currentUser?.id;
                              return _ChatBubble(
                                key: ValueKey(note.id ?? (note.createdAt.toString() + i.toString())),
                                taskId: task.id,
                                note: note,
                                isMe: isMe,
                                isDarkMode: isDarkMode,
                                canDelete: isMe, // FIX 6: ONLY OWNER CAN DELETE
                              );
                            },
                          ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              
              // ── Unified Chat Input Bar ──────────────────────────
              if (canSeeConvo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border(top: BorderSide(color: border)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
                    ]
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_pendingVoiceNotes.isNotEmpty)
                          Container(
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pendingVoiceNotes.length,
                              itemBuilder: (context, i) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.mic, size: 16, color: Theme.of(context).primaryColor),
                                    const SizedBox(width: 4),
                                    Text('Voice ${i+1}', style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor)),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                      onPressed: () => _removePending(i),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                        Row(
                          children: [
                            Expanded(
                              child: _isRecording
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, color: Colors.redAccent, size: 12),
                                          const SizedBox(width: 10),
                                          Text('Recording ${_formatTimer(_recordDuration)}',
                                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).scaffoldBackgroundColor,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: border),
                                      ),
                                      child: TextField(
                                        controller: _chatController,
                                        maxLines: null,
                                        decoration: const InputDecoration(
                                          hintText: 'Type a message...',
                                          hintStyle: TextStyle(fontSize: 14),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          border: InputBorder.none,
                                        ),
                                        onChanged: (v) => setState(() {}),
                                      ),
                                    ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            if (_isRecording)
                              CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                child: IconButton(
                                  icon: const Icon(Icons.stop, color: Colors.white),
                                  onPressed: _stopRecording,
                                ),
                              )
                            else if (_chatController.text.trim().isNotEmpty)
                              CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: IconButton(
                                  icon: const Icon(Icons.send, color: Colors.white),
                                  onPressed: _sendText,
                                ),
                              )
                            else if (_pendingVoiceNotes.isNotEmpty)
                              CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: _isUploading 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                  : IconButton(
                                      icon: const Icon(Icons.send, color: Colors.white),
                                      onPressed: () => _sendVoiceNotes(task.id),
                                    ),
                              )
                            else
                              CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: IconButton(
                                  icon: const Icon(Icons.mic, color: Colors.white),
                                  onPressed: _startRecording,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final String taskId;
  final VoiceNoteModel note;
  final bool isMe;
  final bool isDarkMode;
  final bool canDelete;
  
  const _ChatBubble({
    super.key, 
    required this.taskId,
    required this.note, 
    required this.isMe, 
    required this.isDarkMode,
    required this.canDelete,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.note.isVoice) {
      _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _isPlaying = s == PlayerState.playing); });
      _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
      _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
      _player.onPlayerComplete.listen((_) { if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; }); });
    }
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  void _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      String? url = widget.note.audioUrl;
      if (url == null || url.isEmpty) return;
      if (!url.startsWith('http') && url.startsWith('/')) {
        url = '${ApiService.baseUrl.replaceAll('/api', '')}$url';
      }
      debugPrint('🎙️ Playing audio from $url');
      await _player.play(UrlSource(url, mimeType: 'audio/mpeg'));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('Are you sure you want to remove this message?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      
      if (widget.note.id != null) {
        // FIX 9: DEBUG LOGS
        print("Current user: ${userProvider.currentUser?.id}");
        print("Voice owner: ${widget.note.uploadedBy.id}");
        print("Delete voiceId: ${widget.note.id}");

        final success = await taskProvider.deleteVoiceNote(widget.taskId, widget.note.id!);
        if (!success) {
          if (mounted) {
            _showSnack('You can only delete your own voice note', Colors.red);
          }
        }
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.note.role == 'manager';
    final bubbleColor = widget.isMe 
        ? (widget.isDarkMode ? Theme.of(context).primaryColor.withOpacity(0.2) : Theme.of(context).primaryColor.withOpacity(0.1))
        : (widget.isDarkMode ? Theme.of(context).cardColor : Theme.of(context).cardColor);
    
    final accentColor = isManager ? Theme.of(context).primaryColor : Theme.of(context).primaryColor;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 10, right: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 0),
            bottomRight: Radius.circular(widget.isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!widget.isMe)
                  Text(
                    '${widget.note.uploadedBy.name} (${widget.note.role.toUpperCase()})',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: accentColor,
                    ),
                  )
                else
                  const Spacer(),
                
                if (widget.canDelete)
                  GestureDetector(
                    onTap: _delete,
                    child: Icon(Icons.delete_outline, size: 14, color: Colors.redAccent.withOpacity(0.6)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            
            if (widget.note.isText)
              Text(
                widget.note.text ?? '',
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87, fontSize: 15),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _toggle, 
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            trackHeight: 2,
                          ),
                          child: Slider(
                            value: _position.inMilliseconds.toDouble(),
                            max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                            activeColor: accentColor,
                            inactiveColor: accentColor.withOpacity(0.2),
                            onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatTime(_position), style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                              Text(_formatTime(_duration), style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatDateTime(widget.note.createdAt),
                style: TextStyle(fontSize: 8, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
