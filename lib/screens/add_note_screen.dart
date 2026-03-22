import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../providers/note_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';

class AddNoteScreen extends StatefulWidget {
  final Note? existingNote;
  const AddNoteScreen({super.key, this.existingNote});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'General';
  final List<String> _categories = ['General', 'Work', 'Personal', 'Idea', 'Meeting'];

  // Audio recording
  bool _isRecording = false;
  bool _isPlayingPreview = false;
  String? _recordedFilePath;
  final _audioRecorder = AudioRecorder();
  final _previewPlayer = AudioPlayer();

  // AI state
  bool _isAIProcessing = false;
  String? _aiMode; // 'summarize' | 'improve' | 'tasks'

  // Scan state
  bool _isScanning = false;

  // Animation
  late AnimationController _aiAnimController;
  late Animation<double> _aiPulse;

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      _titleController.text = widget.existingNote!.title;
      _contentController.text = widget.existingNote!.content;
      _selectedCategory = widget.existingNote!.category;
      _recordedFilePath = widget.existingNote!.voiceNotePath;
    }

    _aiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _aiPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _aiAnimController, curve: Curves.easeInOut),
    );

    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlayingPreview = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _audioRecorder.dispose();
    _previewPlayer.dispose();
    _aiAnimController.dispose();
    super.dispose();
  }

  // ─── Voice Recording ─────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/note_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      } else {
        _showSnack('Microphone permission required', isError: true);
      }
    } catch (e) {
      _showSnack('Could not start recording: $e', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } catch (e) {
      setState(() => _isRecording = false);
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _togglePreviewPlayback() async {
    if (_recordedFilePath == null) return;
    if (_isPlayingPreview) {
      await _previewPlayer.stop();
    } else {
      await _previewPlayer.play(DeviceFileSource(_recordedFilePath!));
    }
  }

  // ─── Document Scan / OCR ─────────────────────────────────────────────────

  Future<void> _scanDocument(ImageSource source) async {
    setState(() => _isScanning = true);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 100, // Keep high quality for better OCR
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) {
        setState(() => _isScanning = false);
        return;
      }

      // 1. Image Preprocessing for better OCR accuracy
      final processedFile = await _preprocessImage(pickedFile.path);
      final finalImagePath = processedFile?.path ?? pickedFile.path;

      final inputImage = InputImage.fromFilePath(finalImagePath);
      
      // 2. Multi-language OCR Support (Latin + Devanagari for English, Hindi, Marathi)
      final latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
      
      // Process both scripts to handle mixed language documents
      final results = await Future.wait([
        latinRecognizer.processImage(inputImage),
        devanagariRecognizer.processImage(inputImage),
      ]);
      
      await latinRecognizer.close();
      await devanagariRecognizer.close();

      final latinText = results[0].text;
      final devanagariText = results[1].text;
      
      // 3. Smart Merge / Selection (Optionally combine or pick the most confident/lengthy)
      // If Devanagari model picked up significant text, it likely contains Hindi/Marathi
      String scannedText;
      if (devanagariText.trim().length > latinText.trim().length * 0.3) {
        // Often Devanagari recognizer includes Latin characters too
        scannedText = devanagariText;
      } else {
        scannedText = latinText;
      }

      // 4. Post-processing: Clean extracted text
      scannedText = _cleanExtractedText(scannedText);

      if (scannedText.isNotEmpty) {
        final current = _contentController.text;
        setState(() {
          _contentController.text = current.isEmpty
              ? scannedText
              : '$current\n\n--- Scanned Text ---\n$scannedText';
        });
        _showSnack('✅ Document scanned successfully!');
      } else {
        _showSnack('No text found in image', isError: true);
      }
      
      // Clean up preprocessed file
      if (processedFile != null && await processedFile.exists()) {
        await processedFile.delete();
      }
    } catch (e) {
      _showSnack('Scan failed: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  /// Implements image preprocessing: Grayscale, Contrast, Resize, and Noise reduction
  Future<File?> _preprocessImage(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return null;

      // 1. Convert to Grayscale
      image = img.grayscale(image);
      
      // 2. Increase Contrast (helps OCR distinguish text from background)
      image = img.adjustColor(image, contrast: 1.5);
      
      // 3. Resize if too large (balancing performance and accuracy)
      if (image.width > 2000 || image.height > 2000) {
        image = img.copyResize(
          image, 
          width: image.width > image.height ? 2000 : null,
          height: image.height > image.width ? 2000 : null,
          interpolation: img.Interpolation.linear
        );
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/ocr_prep_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processedFile = File(tempPath);
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 90));
      
      return processedFile;
    } catch (e) {
      debugPrint('Preprocessing error: $e');
      return null;
    }
  }

  /// Cleans extracted text by normalizing spacing and removing OCR artifacts
  String _cleanExtractedText(String text) {
    if (text.isEmpty) return "";
    
    // Normalize line endings and spacing
    String cleaned = text.replaceAll('\r', '\n');
    
    // Remove typical OCR "noise" symbols but keep alphanumeric, punctuation, and Devanagari
    cleaned = cleaned.split('').where((char) {
      final code = char.codeUnitAt(0);
      return (code >= 0x41 && code <= 0x5A) || // A-Z
             (code >= 0x61 && code <= 0x7A) || // a-z
             (code >= 0x30 && code <= 0x39) || // 0-9
             (code >= 0x0900 && code <= 0x097F) || // Devanagari range
             ".,!?:;()-'/\"\n ".contains(char); // Common punctuation and space
    }).join('');

    // Normalize multiple spaces and extra newlines
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return cleaned.trim();
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2F3F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Scan Document', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2ECC71)),
              title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _scanDocument(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF2ECC71)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _scanDocument(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── AI Features ─────────────────────────────────────────────────────────

  /// Simulates AI processing locally (no external API needed).
  /// Replace with real API call if you have an AI backend.
  Future<void> _runAI(String mode) async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnack('Please write some content first', isError: true);
      return;
    }

    setState(() {
      _isAIProcessing = true;
      _aiMode = mode;
    });

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    try {
      switch (mode) {
        case 'summarize':
          await _aiSummarize(content);
          break;
        case 'improve':
          await _aiImprove(content);
          break;
        case 'tasks':
          await _aiConvertToTasks(content);
          break;
      }
    } finally {
      if (mounted) setState(() {
        _isAIProcessing = false;
        _aiMode = null;
      });
    }
  }

  Future<void> _aiSummarize(String content) async {
    // Smart local summarization — take first sentence of each paragraph
    final paragraphs = content
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    String summary;
    if (paragraphs.length <= 2) {
      // Short content: take first 100 chars
      summary = content.length > 150 ? '${content.substring(0, 150)}...' : content;
    } else {
      // Multi-paragraph: first sentence of each paragraph
      final sentences = paragraphs.map((p) {
        final firstDot = p.indexOf('.');
        return firstDot > 0 ? p.substring(0, firstDot + 1) : p;
      }).take(3).join(' ');
      summary = '📝 Summary:\n$sentences';
    }

    _showAIResultDialog(
      title: '✨ AI Summary',
      content: summary,
      onApply: () {
        // Append summary to note
        final updated = '${_contentController.text}\n\n─── AI Summary ───\n$summary';
        setState(() => _contentController.text = updated);
      },
    );
  }

  Future<void> _aiImprove(String content) async {
    // Smart local improvement — fix common patterns
    String improved = content;
    
    // Capitalize sentences
    improved = improved.replaceAllMapped(
      RegExp(r'(?:^|[.!?]\s+)([a-z])'),
      (m) => m[0]!.replaceFirst(m[1]!, m[1]!.toUpperCase()),
    );
    
    // Fix double spaces
    improved = improved.replaceAll(RegExp(r' {2,}'), ' ');
    
    // Fix common typos
    final typoFixes = {
      ' i ': ' I ',
      'dont': "don't",
      'cant': "can't",
      'wont': "won't",
      'isnt': "isn't",
      'wasnt': "wasn't",
      'werent': "weren't",
    };
    for (final entry in typoFixes.entries) {
      improved = improved.replaceAll(entry.key, entry.value);
    }

    _showAIResultDialog(
      title: '✍️ Improved Writing',
      content: improved,
      onApply: () => setState(() => _contentController.text = improved),
    );
  }

  Future<void> _aiConvertToTasks(String content) async {
    // Extract bullet points, numbered lists, and action items
    final lines = content.split('\n');
    final taskLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect action items: bullet points, numbers, action verbs
      final isBullet = trimmed.startsWith('-') || 
                       trimmed.startsWith('•') || 
                       trimmed.startsWith('*') ||
                       RegExp(r'^\d+[\.\)]\s').hasMatch(trimmed);
      
      final hasActionVerb = RegExp(
        r'^(complete|finish|review|update|fix|add|create|send|write|read|call|meet|check|prepare|schedule|draft)',
        caseSensitive: false,
      ).hasMatch(trimmed);

      if (isBullet || hasActionVerb || trimmed.length < 80) {
        // Clean up bullet/number markers
        String taskTitle = trimmed
            .replaceAll(RegExp(r'^[-•*]\s*'), '')
            .replaceAll(RegExp(r'^\d+[\.\)]\s*'), '')
            .trim();
        
        if (taskTitle.isNotEmpty) {
          taskLines.add(taskTitle);
        }
      }
    }

    if (taskLines.isEmpty) {
      // Fallback: use lines as tasks
      taskLines.addAll(
        lines.where((l) => l.trim().isNotEmpty && l.trim().length < 100)
             .take(5)
             .map((l) => l.trim()),
      );
    }

    if (taskLines.isEmpty) {
      _showSnack('Could not extract tasks from this note', isError: true);
      return;
    }

    _showConvertToTasksDialog(taskLines.take(5).toList());
  }

  void _showConvertToTasksDialog(List<String> taskTitles) {
    final selected = List<bool>.filled(taskTitles.length, true);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2F3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🤖 Convert to Tasks',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select tasks to create:',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...taskTitles.asMap().entries.map((entry) {
                return CheckboxListTile(
                  dense: true,
                  activeColor: const Color(0xFF2ECC71),
                  checkColor: Colors.black,
                  value: selected[entry.key],
                  onChanged: (v) => setDialogState(() => selected[entry.key] = v!),
                  title: Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _createTasksFromNote(
                  taskTitles.asMap().entries
                      .where((e) => selected[e.key])
                      .map((e) => e.value)
                      .toList(),
                );
              },
              child: const Text('Create Tasks'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTasksFromNote(List<String> taskTitles) async {
    if (taskTitles.isEmpty) return;

    final taskProvider = context.read<TaskProvider>();
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token ?? '';

    int created = 0;
    for (final title in taskTitles) {
      final task = TaskModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: 'Created from note: ${_titleController.text}',
        createdDate: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
        priority: 'medium',
        category: 'General',
        assignedTo: userProvider.currentUser?.id,
        status: 'pending',
      );

      if (token.isNotEmpty) {
        await taskProvider.addTask(task, token);
      } else {
        taskProvider.addLocalTask(task);
      }
      created++;
    }

    _showSnack('✅ Created $created task${created > 1 ? 's' : ''} successfully!');
  }

  void _showAIResultDialog({
    required String title,
    required String content,
    required VoidCallback onApply,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2F3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1E2B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(ctx);
              _showSnack('Copied to clipboard!');
            },
            child: const Text('Copy', style: TextStyle(color: Color(0xFF2ECC71))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Dismiss', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onApply();
              _showSnack('Applied to note!');
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  void _saveNote() {
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Please enter a title', isError: true);
      return;
    }

    final newNote = Note(
      id: widget.existingNote?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      date: widget.existingNote?.date ?? DateTime.now(),
      category: _selectedCategory,
      voiceNotePath: _recordedFilePath,
    );

    if (widget.existingNote != null) {
      context.read<NoteProvider>().updateNote(newNote);
    } else {
      context.read<NoteProvider>().addNote(newNote);
    }

    Navigator.pop(context);
    _showSnack('Note saved ✅', isError: false);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2ECC71),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1A1E2B) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF2A2F3F) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingNote != null ? 'Edit Note' : 'New Note',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Scan document button
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2ECC71),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.document_scanner_rounded, color: textColor.withOpacity(0.7)),
              tooltip: 'Scan Document',
              onPressed: _showScanOptions,
            ),
          // Save button
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFF2ECC71), size: 28),
            onPressed: _saveNote,
          ),
        ],
      ),

      body: Column(
        children: [
          // AI Processing Banner
          if (_isAIProcessing)
            AnimatedBuilder(
              animation: _aiPulse,
              builder: (_, __) => Opacity(
                opacity: _aiPulse.value,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: const Color(0xFF2ECC71).withOpacity(0.15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2ECC71),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _aiMode == 'summarize'
                            ? '✨ Summarizing note...'
                            : _aiMode == 'improve'
                                ? '✍️ Improving writing...'
                                : '🤖 Extracting tasks...',
                        style: const TextStyle(
                          color: Color(0xFF2ECC71),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Note Editor
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: TextStyle(
                          color: textColor.withOpacity(0.3),
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                        color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  // Meta row
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy · HH:mm').format(DateTime.now()),
                        style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFF2ECC71), size: 16),
                          dropdownColor: const Color(0xFF2A2F3F),
                          onChanged: (val) => setState(() => _selectedCategory = val!),
                          items: _categories
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        style: const TextStyle(
                                            fontSize: 12, color: Color(0xFF2ECC71))),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 32, color: Colors.grey),

                  // Content
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Start writing your thoughts...\n\nTip: Use the AI tools below to summarize, improve, or convert to tasks!',
                      hintStyle: TextStyle(
                          color: textColor.withOpacity(0.3), fontSize: 15, height: 1.6),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
                  ),

                  const SizedBox(height: 32),

                  // Voice note playback
                  if (_recordedFilePath != null)
                    _buildVoiceNoteCard(cardColor, textColor),

                  // AI Toolbar
                  const SizedBox(height: 16),
                  _buildAIToolbar(textColor),
                ],
              ),
            ),
          ),

          // Bottom bar
          _buildBottomBar(textColor),
        ],
      ),
    );
  }

  Widget _buildVoiceNoteCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Color(0xFF2ECC71), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Voice note recorded',
                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13)),
          ),
          IconButton(
            icon: Icon(
              _isPlayingPreview ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: const Color(0xFF2ECC71),
              size: 28,
            ),
            onPressed: _togglePreviewPlayback,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            onPressed: () => setState(() => _recordedFilePath = null),
          ),
        ],
      ),
    );
  }

  Widget _buildAIToolbar(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF2ECC71), size: 14),
            const SizedBox(width: 6),
            Text('AI Tools',
                style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _aiChip(
                icon: Icons.summarize_rounded,
                label: 'Summarize',
                onTap: () => _runAI('summarize'),
                active: _aiMode == 'summarize',
              ),
              const SizedBox(width: 8),
              _aiChip(
                icon: Icons.auto_fix_high_rounded,
                label: 'Improve',
                onTap: () => _runAI('improve'),
                active: _aiMode == 'improve',
              ),
              const SizedBox(width: 8),
              _aiChip(
                icon: Icons.task_alt_rounded,
                label: 'To Tasks',
                onTap: () => _runAI('tasks'),
                active: _aiMode == 'tasks',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aiChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: _isAIProcessing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2ECC71).withOpacity(0.2)
              : const Color(0xFF2A2F3F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFF2ECC71)
                : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: _isAIProcessing && active
                    ? Colors.grey
                    : const Color(0xFF2ECC71)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _isAIProcessing && active
                    ? Colors.grey
                    : const Color(0xFF2ECC71),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(Color textColor) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          left: 16,
          right: 16,
          top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2B),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          // Voice record button (hold to record)
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.redAccent : const Color(0xFF2ECC71),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic_none_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          if (_isRecording)
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.redAccent, size: 8),
                  SizedBox(width: 4),
                  Text('Hold to record...',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const Spacer(),
          // Scan document
          IconButton(
            icon: Icon(Icons.document_scanner_outlined, color: textColor.withOpacity(0.5)),
            tooltip: 'Scan Document',
            onPressed: _showScanOptions,
          ),
          // Character count
          Text(
            '${_contentController.text.length} chars',
            style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
