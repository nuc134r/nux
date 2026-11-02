import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A new random row id (UUID v4).
String newId() => _uuid.v4();

/// Columns every user-data table has, so a future backup/merge can match rows across devices.
/// Set [updatedAt] on every write.
mixin SyncedTable on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device-local key/value settings. Never holds secrets: those go to `SecretStore`.
@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
