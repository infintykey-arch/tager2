import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract interface class NotesRepository {
  Future<List<Note>> getNotes();
  Future<Note> saveNote({
    int? id,
    required String title,
    required String content,
  });
  Future<void> deleteNote(int id);
}

class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Note>> getNotes() async {
    final rows =
        await (_database.select(_database.notes)..orderBy([
              (note) => OrderingTerm.desc(note.updatedAt),
              (note) => OrderingTerm.desc(note.id),
            ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Note> saveNote({
    int? id,
    required String title,
    required String content,
  }) async {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('اكتب اسمًا للملاحظة.');
    if (cleanContent.isEmpty) throw ArgumentError('اكتب محتوى الملاحظة.');
    if (cleanTitle.length > 120 || cleanContent.length > 50000) {
      throw ArgumentError('الملاحظة أطول من الحد المدعوم.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final savedId = await _database.transaction(() async {
      if (id == null) {
        return _database
            .into(_database.notes)
            .insert(
              NotesCompanion.insert(
                title: cleanTitle,
                content: cleanContent,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final existing = await (_database.select(
        _database.notes,
      )..where((note) => note.id.equals(id))).getSingleOrNull();
      if (existing == null) throw StateError('الملاحظة غير موجودة.');
      await (_database.update(
        _database.notes,
      )..where((note) => note.id.equals(id))).write(
        NotesCompanion(
          title: Value(cleanTitle),
          content: Value(cleanContent),
          updatedAt: Value(now),
        ),
      );
      return id;
    });
    final row = await (_database.select(
      _database.notes,
    )..where((note) => note.id.equals(savedId))).getSingle();
    return _toDomain(row);
  }

  @override
  Future<void> deleteNote(int id) async {
    final deleted = await (_database.delete(
      _database.notes,
    )..where((note) => note.id.equals(id))).go();
    if (deleted == 0) throw StateError('الملاحظة غير موجودة.');
  }

  Note _toDomain(NoteRow row) => Note(
    id: row.id,
    title: row.title,
    content: row.content,
    createdAt: DateTime.parse(row.createdAt),
    updatedAt: DateTime.parse(row.updatedAt),
  );
}
