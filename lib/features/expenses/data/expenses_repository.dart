import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';

class ExpenseDraft {
  const ExpenseDraft({
    required this.category,
    required this.amountMinor,
    required this.requestKey,
    this.description,
    this.location,
    this.occurredAt,
  });

  final String category;
  final String? description;
  final String? location;
  final int amountMinor;
  final String requestKey;
  final DateTime? occurredAt;
}

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.category,
    required this.amountMinor,
    required this.occurredAt,
    this.description,
    this.location,
  });

  final int id;
  final String category;
  final String? description;
  final String? location;
  final int amountMinor;
  final DateTime occurredAt;

  factory ExpenseEntry.fromRow(ExpenseRow row) => ExpenseEntry(
    id: row.id,
    category: row.category,
    description: row.description,
    location: row.location,
    amountMinor: row.amountMinor,
    occurredAt: DateTime.parse(row.occurredAt),
  );
}

abstract interface class ExpensesRepository {
  Future<ExpenseEntry> createExpense(ExpenseDraft draft);

  Future<List<ExpenseEntry>> getRecent({int limit = 200});

  Future<List<ExpenseEntry>> getBetween(
    DateTime start,
    DateTime end, {
    int limit = 1000,
  });

  Future<int> getTotalBetween(DateTime start, DateTime end);
}

class DriftExpensesRepository implements ExpensesRepository {
  DriftExpensesRepository(this._database);

  final AppDatabase _database;

  @override
  Future<ExpenseEntry> createExpense(ExpenseDraft draft) async {
    final category = draft.category.trim();
    final requestKey = draft.requestKey.trim();
    if (category.isEmpty) throw ArgumentError('اختر نوع المصروف.');
    if (draft.amountMinor <= 0) {
      throw ArgumentError('قيمة المصروف يجب أن تكون أكبر من صفر.');
    }
    if (requestKey.isEmpty) {
      throw ArgumentError('مفتاح العملية مطلوب لمنع تكرار المصروف.');
    }

    final occurredAt = (draft.occurredAt ?? DateTime.now()).toUtc();
    final occurredAtText = occurredAt.toIso8601String();
    final description = draft.description?.trim();
    final location = draft.location?.trim();
    return _database.transaction(() async {
      final previous =
          await (_database.select(_database.expenses)
                ..where((table) => table.requestKey.equals(requestKey))
                ..limit(1))
              .get();
      if (previous.isNotEmpty) {
        return ExpenseEntry.fromRow(previous.single);
      }

      final id = await _database
          .into(_database.expenses)
          .insert(
            ExpensesCompanion.insert(
              category: category,
              description: Value(
                description == null || description.isEmpty ? null : description,
              ),
              location: Value(
                location == null || location.isEmpty ? null : location,
              ),
              amountMinor: draft.amountMinor,
              requestKey: requestKey,
              occurredAt: occurredAtText,
            ),
          );
      final inserted =
          await (_database.select(_database.expenses)
                ..where((table) => table.id.equals(id))
                ..limit(1))
              .getSingle();
      return ExpenseEntry.fromRow(inserted);
    });
  }

  @override
  Future<List<ExpenseEntry>> getRecent({int limit = 200}) async {
    if (limit <= 0) return const [];
    final rows =
        await (_database.select(_database.expenses)
              ..orderBy([
                (table) => OrderingTerm.desc(table.occurredAt),
                (table) => OrderingTerm.desc(table.id),
              ])
              ..limit(limit))
            .get();
    return rows.map(ExpenseEntry.fromRow).toList(growable: false);
  }

  @override
  Future<List<ExpenseEntry>> getBetween(
    DateTime start,
    DateTime end, {
    int limit = 1000,
  }) async {
    if (limit <= 0 || !end.isAfter(start)) return const [];
    final startText = start.toUtc().toIso8601String();
    final endText = end.toUtc().toIso8601String();
    final rows =
        await (_database.select(_database.expenses)
              ..where(
                (table) =>
                    table.occurredAt.isBiggerOrEqualValue(startText) &
                    table.occurredAt.isSmallerThanValue(endText),
              )
              ..orderBy([
                (table) => OrderingTerm.desc(table.occurredAt),
                (table) => OrderingTerm.desc(table.id),
              ])
              ..limit(limit))
            .get();
    return rows.map(ExpenseEntry.fromRow).toList(growable: false);
  }

  @override
  Future<int> getTotalBetween(DateTime start, DateTime end) async {
    final rows = await _database
        .customSelect(
          '''
          SELECT COALESCE(SUM(amount_minor), 0) AS total_minor
          FROM expenses
          WHERE occurred_at >= ? AND occurred_at < ?
          ''',
          variables: [
            Variable.withString(start.toUtc().toIso8601String()),
            Variable.withString(end.toUtc().toIso8601String()),
          ],
        )
        .get();
    return rows.single.read<int>('total_minor');
  }
}
