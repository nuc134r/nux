import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

class WorkspaceRepository {
  WorkspaceRepository(this._db);

  final AppDatabase _db;

  /// Most recently opened first.
  Stream<List<Workspace>> watchAll() =>
      (_db.select(_db.workspaces)..orderBy([
            (w) => OrderingTerm(expression: w.lastOpenedAt, mode: OrderingMode.desc, nulls: NullsOrder.last),
            (w) => OrderingTerm(expression: w.name),
          ]))
          .watch();

  Future<Workspace?> get(String id) => (_db.select(_db.workspaces)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<String> create({required String name, required String connectionId, required String rootPath}) async {
    final now = clock.now();
    final id = newId();
    await _db
        .into(_db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            id: Value(id),
            createdAt: now,
            updatedAt: now,
            name: name,
            connectionId: connectionId,
            rootPath: rootPath,
          ),
        );
    return id;
  }

  Future<void> rename(String id, String name) => (_db.update(
    _db.workspaces,
  )..where((w) => w.id.equals(id))).write(WorkspacesCompanion(name: Value(name), updatedAt: Value(clock.now())));

  Future<void> touch(String id) => (_db.update(_db.workspaces)..where((w) => w.id.equals(id))).write(
    WorkspacesCompanion(lastOpenedAt: Value(clock.now()), updatedAt: Value(clock.now())),
  );

  Future<void> delete(String id) => (_db.delete(_db.workspaces)..where((w) => w.id.equals(id))).go();
}

final workspaceRepositoryProvider = Provider((ref) => WorkspaceRepository(ref.watch(appDatabaseProvider)));

final workspacesProvider = StreamProvider<List<Workspace>>((ref) => ref.watch(workspaceRepositoryProvider).watchAll());
