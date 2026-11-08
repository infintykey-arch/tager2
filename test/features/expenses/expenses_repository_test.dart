import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/expenses/data/expenses_repository.dart';

void main() {
  late AppDatabase database;
  late DriftExpensesRepository expenses;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    expenses = DriftExpensesRepository(database);
  });

  tearDown(() => database.close());

  test('يحفظ المصروف ويجمعه ضمن اليوم المحلي المحدد', () async {
    final entry = await expenses.createExpense(
      ExpenseDraft(
        category: 'نقل',
        description: 'توصيل طلبية',
        location: 'السوق',
        amountMinor: 12550,
        requestKey: 'expense-transport-1',
        occurredAt: DateTime.utc(2026, 11, 4, 10),
      ),
    );

    expect(entry.category, 'نقل');
    expect(entry.description, 'توصيل طلبية');
    expect(entry.location, 'السوق');
    expect(entry.amountMinor, 12550);
    expect(
      await expenses.getTotalBetween(
        DateTime.utc(2026, 11, 4),
        DateTime.utc(2026, 11, 5),
      ),
      12550,
    );
    expect(await expenses.getRecent(), hasLength(1));
    final ranged = await expenses.getBetween(
      DateTime.utc(2026, 11, 4),
      DateTime.utc(2026, 11, 5),
    );
    expect(ranged, hasLength(1));
    expect(ranged.single.id, entry.id);
  });

  test('مفتاح التكرار لا يسجل المصروف نفسه مرتين', () async {
    final draft = ExpenseDraft(
      category: 'إيجار',
      amountMinor: 20000,
      requestKey: 'expense-rent-1',
      occurredAt: DateTime.utc(2026, 11, 4),
    );

    final first = await expenses.createExpense(draft);
    final repeated = await expenses.createExpense(draft);

    expect(repeated.id, first.id);
    expect(await expenses.getRecent(), hasLength(1));
    expect(
      await expenses.getTotalBetween(
        DateTime.utc(2026, 11, 4),
        DateTime.utc(2026, 11, 5),
      ),
      20000,
    );
  });

  test('المجموع يستثني وقت النهاية ويرفض المبلغ الصفري', () async {
    await expenses.createExpense(
      ExpenseDraft(
        category: 'مرافق',
        amountMinor: 100,
        requestKey: 'expense-boundary-1',
        occurredAt: DateTime.utc(2026, 11, 5),
      ),
    );

    expect(
      await expenses.getTotalBetween(
        DateTime.utc(2026, 11, 4),
        DateTime.utc(2026, 11, 5),
      ),
      0,
    );
    await expectLater(
      expenses.createExpense(
        const ExpenseDraft(
          category: 'أخرى',
          amountMinor: 0,
          requestKey: 'expense-zero',
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
