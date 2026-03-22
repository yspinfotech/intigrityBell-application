import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/note_model.dart';

class NoteProvider extends ChangeNotifier {
  List<Note> _notes = [];
  bool _isLoading = false;
  static const String _notesKey = 'user_notes';

  NoteProvider() {
    _loadNotes();
  }

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;

  Future<void> _loadNotes() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_notesKey);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        _notes = jsonList.map((e) => Note.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_notes.map((e) => e.toJson()).toList());
      await prefs.setString(_notesKey, encoded);
    } catch (e) {
      debugPrint('Error saving notes: $e');
    }
  }

  void addNote(Note note) {
    _notes.insert(0, note); // Newest first
    _saveNotes();
    notifyListeners();
  }

  void updateNote(Note note) {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      _saveNotes();
      notifyListeners();
    }
  }

  void deleteNote(String noteId) {
    _notes.removeWhere((n) => n.id == noteId);
    _saveNotes();
    notifyListeners();
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return _notes;
    return _notes.where((n) => 
      n.title.toLowerCase().contains(query.toLowerCase()) ||
      n.content.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
}
