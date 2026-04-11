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
import 'package:permission_handler/permission_handler.dart';
import '../services/smart_ai_service.dart';
import '../utils/language_utils.dart';

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

class _AddNoteScreenState extends State<AddNoteScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'General';
  final List<String> _categories = [
    'General',
    'Work',
    'Personal',
    'Idea',
    'Meeting',
  ];

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
  String? _scannedImagePath;
  String? _detectedLanguageCode;

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
      _scannedImagePath = widget.existingNote!.scannedImagePath;
    }

    _aiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _aiPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _aiAnimController, curve: Curves.easeInOut),
    );

    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted)
        setState(() => _isPlayingPreview = state == PlayerState.playing);
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
        final path =
            '${dir.path}/note_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    // 1. Check Permissions
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      _showSnack(
        'Permission required to scan and save documents',
        isError: true,
      );
      return;
    }

    setState(() => _isScanning = true);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) {
        setState(() => _isScanning = false);
        return;
      }

      // 2. Image Preprocessing (Improved)
      final processedFile = await _preprocessImage(pickedFile.path);
      final finalImagePath = processedFile?.path ?? pickedFile.path;

      final inputImage = InputImage.fromFilePath(finalImagePath);

      // 3. OCR — Dual script strategy (Devanagari + Latin)
      final devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
      final devanagariResult = await devanagariRecognizer.processImage(inputImage);
      await devanagariRecognizer.close();

      final latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final latinResult = await latinRecognizer.processImage(inputImage);
      await latinRecognizer.close();

      final bool richDevanagari = devanagariResult.text.trim().length > 5;
      final bool richLatin = latinResult.text.trim().length > 5;

      // Merge all snippets for detection
      String mergedScanText;
      if (richDevanagari && richLatin) {
        mergedScanText = '${devanagariResult.text} ${latinResult.text}';
      } else if (richDevanagari) {
        mergedScanText = devanagariResult.text;
      } else {
        mergedScanText = latinResult.text;
      }

      // --- Handwriting Fallback Detection ---
      // Trigger AI OCR if text is short, highly fragmented, or empty
      final bool isHandwrittenHeuristic = 
          mergedScanText.trim().isEmpty || 
          mergedScanText.trim().length < 20 || 
          mergedScanText.split('\n').length > mergedScanText.length / 5;

      if (isHandwrittenHeuristic) {
        _showSnack('Handwriting or low quality detected. Enhancing with AI...', isError: false);
        try {
          final aiResult = await SmartAiService.performAiOcr(finalImagePath);
          if (aiResult.isNotEmpty && aiResult.length > mergedScanText.length) {
            mergedScanText = aiResult;
          }
        } catch (e) {
          debugPrint('Handwriting OCR Fallback failed: $e');
        }
      }

      if (mergedScanText.trim().isNotEmpty) {
        final String langCode = await SmartAiService.detectLanguageSmart(mergedScanText);
        final String langLabel = LanguageUtils.getLanguageLabel(langCode);

        final cleanedText = _cleanTextImproved(mergedScanText);
        final current = _contentController.text;

        setState(() {
          _detectedLanguageCode = langCode;
          _contentController.text = current.isEmpty
              ? cleanedText
              : '$current\n\n--- Scanned ($langLabel) ---\n$cleanedText';
        });

        // 6. Secure Local Storage (Image + Text)
        final savedPath = await _saveScanToLocalStorage(
          pickedFile.path,
          cleanedText,
        );
        setState(() => _scannedImagePath = savedPath);

        _showSnack('✅ Scanned ($langLabel) & saved!');
      } else {
        _showSnack('No text found. Try better lighting or hold steady.', isError: true);
      }

      if (processedFile != null && await processedFile.exists()) {
        await processedFile.delete();
      }
    } catch (e) {
      _showSnack('Scan failed: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<bool> _checkPermissions() async {
    // Basic permissions for Android and iOS
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      if (Platform.isAndroid) ...[
        if (await _isAndroid13OrHigher()) 
          Permission.photos 
        else 
          Permission.storage,
      ],
    ].request();

    // Check MANAGE_EXTERNAL_STORAGE for custom directory access on Android 11+
    if (Platform.isAndroid && await _isAndroid11OrHigher()) {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      if (statuses.values.any((status) => status.isPermanentlyDenied)) {
        openAppSettings();
      } else {
        _showSnack('Permission required to scan and save documents', isError: true);
      }
    }
    return allGranted;
  }

  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    return true;
  }

  Future<bool> _isAndroid11OrHigher() async {
    if (!Platform.isAndroid) return false;
    return true;
  }

  /// Implements image preprocessing: Grayscale, Contrast, and Noise reduction
  Future<File?> _preprocessImage(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      // 1. Convert to Grayscale
      image = img.grayscale(image);

      // 2. Sharpening Filter (Convolution) to enhance pen strokes
      final sharpenKernel = [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0
      ];
      image = img.convolution(image, filter: sharpenKernel);

      // 3. Noise Reduction (Gaussian Blur)
      image = img.gaussianBlur(image, radius: 1);

      // 4. Contrast & Brightness Adjustment
      image = img.adjustColor(image, contrast: 1.8, brightness: 1.1);

      // 5. Binary Thresholding (B&W conversion for sharp OCR)
      const int threshold = 140; // Adjustable based on image brightness
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          // luminence = r*0.3 + g*0.59 + b*0.11
          final luminance = (pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11).toInt();
          if (luminance < threshold) {
            image.setPixelRgba(x, y, 0, 0, 0, 255); // Black
          } else {
            image.setPixelRgba(x, y, 255, 255, 255, 255); // White
          }
        }
      }

      // 6. Resize if too large
      if (image.width > 2000 || image.height > 2000) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 2000 : null,
          height: image.height > image.width ? 2000 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/ocr_prep_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processedFile = File(tempPath);
      // Save it asynchronously by wrapping in wait
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: 90));

      return processedFile;
    } catch (e) {
      debugPrint('Preprocessing error: $e');
      return null;
    }
  }

  String _cleanTextImproved(String text) {
    if (text.isEmpty) return "";
    // Normalize and keep letters, Devanagari, numbers, and common punctuation/spaces
    return text
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0900-\u097F\s.,!?:;#@\(\)\[\]-]'), '')
        .trim();
  }

  Future<String?> _saveScanToLocalStorage(
    String originalImagePath,
    String text,
  ) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        // android: /storage/emulated/0/Integrity-Bell/
        directory = Directory('/storage/emulated/0/Integrity-Bell');
      } else {
        // ios: Application Documents Directory
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) await directory.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Save scanned images as files (.jpg)
      final imageFile = File(originalImagePath);
      final String extension = imageFile.path.split('.').last.toLowerCase();
      final String fileName = 'scan_$timestamp.${extension.isEmpty ? 'jpg' : extension}';
      
      final savedImageFile = await imageFile.copy('${directory.path}/$fileName');

      // OCR text is saved inside the Note model and JSON system (Provider handles this).
      // We don't necessarily need a text file here, but can keep as local backup if desired.
      // But the requirement says "Save OCR text inside note JSON".
      
      return savedImageFile.path;
    } catch (e) {
      debugPrint('Local storage error: $e');
      return null;
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
            const Text(
              'Scan Document',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.camera_alt_rounded,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                'Take a Photo',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                _scanDocument(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                'Choose from Gallery',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
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

    try {
      String result = "";
      switch (mode) {
        case 'summarize':
          result = await SmartAiService.summarize(content);
          _showAIResultDialog(
            title: '✨ AI Summary',
            content: result,
            onApply: () {
              final updated = '${_contentController.text}\n\n─── AI Summary ───\n$result';
              setState(() => _contentController.text = updated);
            },
          );
          break;
        case 'rewrite':
          result = await SmartAiService.rewrite(content);
          _showAIResultDialog(
            title: '✍️ AI Rewrite',
            content: result,
            onApply: () => setState(() => _contentController.text = result),
          );
          break;
        case 'points':
          result = await SmartAiService.convertToBulletPoints(content);
          _showAIResultDialog(
            title: '📝 AI Key Points',
            content: result,
            onApply: () {
              final updated = '${_contentController.text}\n\n─── Key Points ───\n$result';
              setState(() => _contentController.text = updated);
            },
          );
          break;
        case 'list':
          result = await SmartAiService.convertToNumberedList(content);
          _showAIResultDialog(
            title: '🔢 Numbered List',
            content: result,
            onApply: () {
              final updated = '${_contentController.text}\n\n─── Numbered List ───\n$result';
              setState(() => _contentController.text = updated);
            },
          );
          break;
        case 'table':
          result = await SmartAiService.convertToTable(content);
          _showAIResultDialog(
            title: '📊 Data Table',
            content: result,
            onApply: () {
              final updated = '${_contentController.text}\n\n$result';
              setState(() => _contentController.text = updated);
            },
          );
          break;
        case 'translate':
          await _showTranslationDialog(content);
          break;
        case 'tasks':
          await _aiConvertToTasks(content);
          break;
      }
    } catch (e) {
      _showSnack('AI processing failed. Check API key or connection.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isAIProcessing = false;
          _aiMode = null;
        });
      }
    }
  }

  Future<void> _showTranslationDialog(String content) async {
    final targetLanguages = {
      'en': 'English',
      'hi': 'Hindi',
      'mr': 'Marathi',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
    };

    String? selectedLang = 'en';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🌐 Translate to...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: targetLanguages.entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              onTap: () {
                selectedLang = entry.key;
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );

    if (selectedLang != null) {
      setState(() => _isAIProcessing = true);
      try {
        final result = await SmartAiService.translate(content, targetLanguages[selectedLang!]!);
        _showAIResultDialog(
          title: '🌐 AI Translation (${targetLanguages[selectedLang]})',
          content: result,
          onApply: () {
            final updated = '${_contentController.text}\n\n─── Translated ───\n$result';
            setState(() => _contentController.text = updated);
          },
        );
      } catch (e) {
        _showSnack('Translation failed', isError: true);
      }
    }
  }

  Future<void> _aiConvertToTasks(String content) async {
    // Extract bullet points, numbered lists, and action items
    final lines = content.split('\n');
    final taskLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect action items: bullet points, numbers, action verbs
      final isBullet =
          trimmed.startsWith('-') ||
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
        lines
            .where((l) => l.trim().isNotEmpty && l.trim().length < 100)
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
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '🤖 Convert to Tasks',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 16),
          ),
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
                  activeColor: Theme.of(context).primaryColor,
                  checkColor: Colors.white,
                  value: selected[entry.key],
                  onChanged: (v) =>
                      setDialogState(() => selected[entry.key] = v!),
                  title: Text(
                    entry.value,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 13),
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
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _createTasksFromNote(
                  taskTitles
                      .asMap()
                      .entries
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

    _showSnack(
      '✅ Created $created task${created > 1 ? 's' : ''} successfully!',
    );
  }

  void _showAIResultDialog({
    required String title,
    required String content,
    required VoidCallback onApply,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(ctx);
              _showSnack('Copied to clipboard!');
            },
            child: Text(
              'Copy',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Dismiss', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
      id:
          widget.existingNote?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      date: widget.existingNote?.date ?? DateTime.now(),
      category: _selectedCategory,
      voiceNotePath: _recordedFilePath,
      scannedImagePath: _scannedImagePath,
    );

    if (widget.existingNote != null) {
      context.read<NoteProvider>().updateNote(newNote);
    } else {
      context.read<NoteProvider>().addNote(newNote);
    }

    Navigator.pop(context);
    _showSnack('Note saved ✅', isError: false);
  }

  Widget _buildAIActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: Theme.of(context).primaryColor),
        label: Text(label),
        onPressed: onPressed,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.05),
        labelStyle: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.2)),
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.redAccent
            : Theme.of(context).primaryColor,
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
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        actions: [
          // Scan document button
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.document_scanner_rounded,
                color: textColor.withOpacity(0.7),
              ),
              tooltip: 'Scan Document',
              onPressed: _showScanOptions,
            ),
          // Save button
          IconButton(
            icon: Icon(
              Icons.check_rounded,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  color: Theme.of(context).primaryColor.withOpacity(0.15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _aiMode == 'summarize'
                            ? '✨ Summarizing note...'
                            : _aiMode == 'rewrite'
                            ? '✍️ Rewriting note...'
                            : _aiMode == 'translate'
                            ? '🌐 Translating...'
                            : _aiMode == 'points'
                            ? '📝 Extracting points...'
                            : _aiMode == 'list'
                            ? '🔢 Formatting list...'
                            : _aiMode == 'table'
                            ? '📊 Creating table...'
                            : '🤖 Extracting tasks...',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
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
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),

                  // Meta row
                  Row(
                    children: [
                      Text(
                        DateFormat(
                          'MMM dd, yyyy · HH:mm',
                        ).format(DateTime.now()),
                        style: TextStyle(
                          color: textColor.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          underline: const SizedBox(),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).primaryColor,
                            size: 16,
                          ),
                          dropdownColor: Theme.of(context).cardColor,
                          onChanged: (val) =>
                              setState(() => _selectedCategory = val!),
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              )
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
                      hintText:
                          'Start writing your thoughts...\n\nTip: Use the AI tools below to summarize, improve, or convert to tasks!',
                      hintStyle: TextStyle(
                        color: textColor.withOpacity(0.3),
                        fontSize: 15,
                        height: 1.6,
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // AI Action Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAIActionButton(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Summarize',
                          onPressed: () => _runAI('summarize'),
                        ),
                        _buildAIActionButton(
                          icon: Icons.edit_note_rounded,
                          label: 'Rewrite',
                          onPressed: () => _runAI('rewrite'),
                        ),
                        _buildAIActionButton(
                          icon: Icons.format_list_bulleted_rounded,
                          label: 'Points',
                          onPressed: () => _runAI('points'),
                        ),
                        _buildAIActionButton(
                          icon: Icons.format_list_numbered_rounded,
                          label: 'List',
                          onPressed: () => _runAI('list'),
                        ),
                        _buildAIActionButton(
                          icon: Icons.table_chart_rounded,
                          label: 'Table',
                          onPressed: () => _runAI('table'),
                        ),
                        _buildAIActionButton(
                          icon: Icons.translate_rounded,
                          label: 'Translate',
                          onPressed: () => _runAI('translate'),
                        ),
                        _buildAIActionButton(
                          icon: Icons.checklist_rtl_rounded,
                          label: 'To Tasks',
                          onPressed: () => _runAI('tasks'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Voice note playback
                  if (_recordedFilePath != null)
                    _buildVoiceNoteCard(cardColor, textColor),
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
            child: Text(
              'Voice note recorded',
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(
              _isPlayingPreview
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: const Color(0xFF2ECC71),
              size: 28,
            ),
            onPressed: _togglePreviewPlayback,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            onPressed: () => setState(() => _recordedFilePath = null),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Color textColor) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        left: 16,
        right: 16,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFF1A237E).withOpacity(0.05)),
        ),
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
                color: _isRecording
                    ? Colors.redAccent
                    : Theme.of(context).primaryColor,
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
                  Text(
                    'Hold to record...',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_detectedLanguageCode != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Text(
                LanguageUtils.getLanguageLabel(_detectedLanguageCode!),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          // Scan document
          IconButton(
            icon: Icon(
              Icons.document_scanner_outlined,
              color: textColor.withOpacity(0.5),
            ),
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
