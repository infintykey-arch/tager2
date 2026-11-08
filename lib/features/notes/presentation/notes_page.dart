import 'package:flutter/material.dart';

import '../data/notes_repository.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.repository});

  final NotesRepository repository;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late Future<List<Note>> _notesFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notesFuture = widget.repository.getNotes();
  }

  void _reload() {
    setState(() {
      _notesFuture = widget.repository.getNotes();
    });
  }

  Future<void> _createNote() async {
    final input = await _showEditor();
    if (input == null) return;
    await _save(title: input.title, content: input.content);
  }

  Future<void> _openNote(Note note) async {
    final action = await showDialog<_NoteAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: SingleChildScrollView(child: SelectableText(note.content)),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_NoteAction.edit),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_NoteAction.close),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == _NoteAction.close) return;
    if (action == _NoteAction.edit) {
      final input = await _showEditor(note: note);
      if (input != null) {
        await _save(id: note.id, title: input.title, content: input.content);
      }
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملاحظة؟'),
        content: Text('سيتم حذف «${note.title}». لا يمكن التراجع عن ذلك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteNote(note.id);
      _reload();
      _showMessage('تم حذف الملاحظة.');
    } catch (error) {
      _showMessage('تعذر حذف الملاحظة: $error');
    }
  }

  Future<_NoteInput?> _showEditor({Note? note}) => showDialog<_NoteInput>(
    context: context,
    builder: (_) => _NoteEditorDialog(note: note),
  );

  Future<void> _save({
    int? id,
    required String title,
    required String content,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveNote(id: id, title: title, content: content);
      if (!mounted) return;
      _reload();
      _showMessage(id == null ? 'تم حفظ الملاحظة.' : 'تم تحديث الملاحظة.');
    } catch (error) {
      _showMessage('تعذر حفظ الملاحظة: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _createNote,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('ملاحظة جديدة'),
      ),
      body: FutureBuilder<List<Note>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('تعذر تحميل الملاحظات: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snapshot.data!;
          if (notes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 52),
                    SizedBox(height: 12),
                    Text('لا توجد ملاحظات بعد. أنشئ أول ملاحظة من الزر أدناه.'),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 96),
            itemCount: notes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.sticky_note_2_outlined),
                  ),
                  title: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'إجراءات الملاحظة',
                    onSelected: (_) => _deleteNote(note),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف الملاحظة'),
                      ),
                    ],
                  ),
                  onTap: () => _openNote(note),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _NoteAction { edit, close }

class _NoteInput {
  const _NoteInput(this.title, this.content);
  final String title;
  final String content;
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({this.note});

  final Note? note;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = 'اكتب اسم الملاحظة ومحتواها أولًا.');
      return;
    }
    Navigator.of(context).pop(_NoteInput(title, content));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'اسم الملاحظة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                minLines: 5,
                maxLines: 12,
                maxLength: 50000,
                decoration: const InputDecoration(labelText: 'المحتوى'),
              ),
              if (_error != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}
