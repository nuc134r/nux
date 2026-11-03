import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

class ForwardRuleRepository {
  ForwardRuleRepository(this._db);

  final AppDatabase _db;

  Stream<List<ForwardRule>> watchAll() => (_db.select(_db.forwardRules)
        ..orderBy([(r) => OrderingTerm(expression: r.sortOrder), (r) => OrderingTerm(expression: r.bindPort)]))
      .watch();

  Future<List<ForwardRule>> all() => _db.select(_db.forwardRules).get();

  Future<ForwardRule?> get(String id) => (_db.select(_db.forwardRules)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Inserts or updates; returns the id.
  Future<String> save(ForwardRulesCompanion data) async {
    final now = clock.now();
    if (data.id.present) {
      await (_db.update(_db.forwardRules)..where((r) => r.id.equals(data.id.value))).write(data.copyWith(updatedAt: Value(now)));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.forwardRules).insert(data.copyWith(id: Value(id), createdAt: Value(now), updatedAt: Value(now)));
    return id;
  }

  Future<void> delete(String id) => (_db.delete(_db.forwardRules)..where((r) => r.id.equals(id))).go();
}

final forwardRuleRepositoryProvider = Provider((ref) => ForwardRuleRepository(ref.watch(appDatabaseProvider)));

final forwardRulesProvider = StreamProvider<List<ForwardRule>>((ref) => ref.watch(forwardRuleRepositoryProvider).watchAll());
