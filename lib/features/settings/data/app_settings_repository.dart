import '../../../data/local/app_database.dart';

abstract interface class AppSettingsRepository {
  Future<bool> loadDarkTheme();

  Future<void> saveDarkTheme(bool enabled);
}

class DriftAppSettingsRepository implements AppSettingsRepository {
  DriftAppSettingsRepository(this._database);

  static const _themeModeKey = 'theme_mode';

  final AppDatabase _database;

  @override
  Future<bool> loadDarkTheme() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where((table) => table.preferenceKey.equals(_themeModeKey))
              ..limit(1))
            .getSingleOrNull();
    return row?.value == 'dark';
  }

  @override
  Future<void> saveDarkTheme(bool enabled) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            preferenceKey: _themeModeKey,
            value: enabled ? 'dark' : 'light',
          ),
        );
  }
}
