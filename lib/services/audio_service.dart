import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isRecording = false;
  bool isPlaying = false;
  String? recordFilePath;

  // Start recording
  Future<String?> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(),
          path: path,
        );
        isRecording = true;
        recordFilePath = path;
        return path;
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
    return null;
  }

  // Stop recording
  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      isRecording = false;
      recordFilePath = path;
      return path;
    } catch (e) {
      debugPrint('Error stopping record: $e');
      return null;
    }
  }

  // Play audio from URL (or local file if file:// prefixed)
  Future<void> playAudio(String url) async {
    try {
      if (url.startsWith('http') || url.startsWith('https')) {
         await _audioPlayer.play(UrlSource(url));
      } else {
         await _audioPlayer.play(DeviceFileSource(url));
      }
      isPlaying = true;
      
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          isPlaying = false;
        }
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    isPlaying = false;
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}
