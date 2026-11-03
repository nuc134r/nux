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

/// A saved SSH host. Authentication tries [identityIds] in order, then the password
/// (saved in `SecretStore` as `password:<id>` when [savePassword]), then keyboard-interactive.
class Connections extends Table with SyncedTable {
  TextColumn get name => text()();
  TextColumn get host => text()();
  IntColumn get port => integer().withDefault(const Constant(22))();
  TextColumn get username => text()();

  /// JSON list of identity ids, in the order they are offered.
  TextColumn get identityIds => text().withDefault(const Constant('[]'))();
  BoolColumn get savePassword => boolean().withDefault(const Constant(false))();

  /// Connect through this connection first (ProxyJump).
  TextColumn get jumpHostId => text().nullable().references(Connections, #id, onDelete: KeyAction.setNull)();
  TextColumn get groupName => text().nullable()();

  /// ARGB colour tag, shown on tabs and in the list.
  IntColumn get color => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get keepAliveSeconds => integer().withDefault(const Constant(15))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}

/// An SSH key. The private key lives in `SecretStore` as `key:<id>` (OpenSSH format, encrypted with
/// the key's passphrase when [encrypted]); this row holds only public information.
class Identities extends Table with SyncedTable {
  TextColumn get name => text()();

  /// `ssh-ed25519`, `ecdsa-sha2-nistp256`, `ssh-rsa`, …
  TextColumn get algorithm => text()();
  IntColumn get bits => integer()();

  /// The `authorized_keys` line.
  TextColumn get publicKey => text()();

  /// `SHA256:…`
  TextColumn get fingerprint => text()();
  BoolColumn get encrypted => boolean().withDefault(const Constant(false))();
  BoolColumn get requireBiometric => boolean().withDefault(const Constant(false))();
}

/// Host keys the user trusted (trust on first use).
class KnownHosts extends Table with SyncedTable {
  TextColumn get host => text()();
  IntColumn get port => integer()();
  TextColumn get keyType => text()();

  /// `SHA256:…`
  TextColumn get fingerprint => text()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {host, port, keyType},
      ];
}

/// Folders saved for quick access in a host's file browser.
class Bookmarks extends Table with SyncedTable {
  TextColumn get connectionId => text().references(Connections, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get name => text()();
}
