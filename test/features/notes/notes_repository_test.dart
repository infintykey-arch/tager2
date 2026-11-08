import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/data/local/app_database.dart';
import 'package:tager2/features/notes/data/notes_repository.dart';

void main() {
  late AppDatabase database;
  late DriftNotesRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftNotesRepository(database);
  });

  tearDown(() => database.close());

  test('يحفظ الملاحظة ويعدلها مع الاحتفاظ بتاريخ الإنشاء ثم يحذفها', () async {
    final created = await repository.saveNote(
      title: '  قائمة الموردين  ',
      content: '  اتصل بمورد الأرز  ',
    );
    expect(created.title, 'قائمة الموردين');
    expect(created.content, 'اتصل بمورد الأرز');
    expect(created.createdAt, created.updatedAt);

    final edited = await repository.saveNote(
      id: created.id,
      title: 'موردون الأسبوع',
      content: 'الأرز والسكر والزيت',
    );
    expect(edited.id, created.id);
    expect(edited.createdAt, created.createdAt);
    expect(edited.updatedAt.isBefore(created.updatedAt), isFalse);
    expect((await repository.getNotes()).single.title, 'موردون الأسبوع');

    await repository.deleteNote(created.id);
    expect(await repository.getNotes(), isEmpty);
    await expectLater(repository.deleteNote(created.id), throwsStateError);
  });

  test('يرفض الملاحظات التي لا تحتوي اسمًا أو محتوى', () async {
    await expectLater(
      repository.saveNote(title: '  ', content: 'نص'),
      throwsArgumentError,
    );
    await expectLater(
      repository.saveNote(title: 'عنوان', content: '  '),
      throwsArgumentError,
    );
    expect(await repository.getNotes(), isEmpty);
  });
}
