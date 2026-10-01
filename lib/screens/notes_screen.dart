import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_item.dart';
import '../services/storage_service.dart';
import '../widgets/note_card.dart';

class NotesScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const NotesScreen({super.key, required this.onDataChanged});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteItem> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final list = await StorageService.loadNotes();
    setState(() {
      _notes = list;
      _isLoading = false;
    });
  }

  Future<void> _deleteNote(NoteItem item) async {
    setState(() {
      _notes.removeWhere((e) => e.id == item.id);
    });
    await StorageService.saveNotes(_notes);
    widget.onDataChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not silindi.')),
    );
  }

  Future<void> _showAddManualDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('Yeni Not'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Not Başlığı',
                  hintText: 'Örn: Alışveriş Listesi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Not İçeriği',
                  hintText: 'Detayları buraya yazabilirsiniz...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty && content.isEmpty) return;

              final newNote = NoteItem(
                id: const Uuid().v4(),
                title: title.isNotEmpty ? title : 'Hızlı Not',
                content: content.isNotEmpty ? content : title,
              );

              setState(() {
                _notes.insert(0, newNote);
              });

              await StorageService.saveNotes(_notes);
              widget.onDataChanged();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _notes.where((n) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm Notlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_rounded),
            onPressed: _showAddManualDialog,
            tooltip: 'Elle Ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Notlarda ara...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notes_rounded,
                                  size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 12),
                              Text(
                                'Kayıtlı not bulunamadı',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mikrofon tuşuna basıp "Not al..." diyebilirsiniz',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final n = filtered[idx];
                            return NoteCard(
                              note: n,
                              onDelete: () => _deleteNote(n),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Elle Ekle'),
      ),
    );
  }
}
