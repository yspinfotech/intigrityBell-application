import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import 'add_note_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1A1E2B) : const Color(0xFFF5F7FA);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

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
          'Personal Notes',
          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-note'),
        backgroundColor: const Color(0xFF2ECC71),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF2A2F3F) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: Consumer<NoteProvider>(
              builder: (context, noteProvider, child) {
                final notes = noteProvider.searchNotes(_searchQuery);

                if (noteProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
                }

                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_alt_outlined, size: 64, color: textColor.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text('No notes found', style: TextStyle(color: textColor.withOpacity(0.5))),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _buildNoteCard(context, note, isDarkMode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note, bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF2A2F3F) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddNoteScreen(existingNote: note)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (note.isAIGenerated)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                  ),
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  note.dateString,
                  style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 10),
                ),
                if (note.voiceNotePath != null)
                  Icon(Icons.mic, color: textColor.withOpacity(0.4), size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
