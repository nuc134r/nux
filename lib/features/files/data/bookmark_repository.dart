import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

class BookmarkRepository {
  BookmarkRepository(this._db);

  final AppDatabase _db;

  Stream<List<Bookmark>> watch(String connectionId) => (_db.select(_db.bookmarks)
        ..where((b) => b.connectionId.equals(connectionId))
        ..orderBy([(b) => OrderingTerm(expression: b.name.lower())]))
      .watch();

  Future<void> add(String connectionId, String path, String name) {
    final now = clock.now();
    return _db.into(_db.bookmarks).insert(BookmarksCompanion.insert(
          connectionId: connectionId,
          path: path,
          name: name,
          createdAt: now,
          updatedAt: now,
        ));
  }

  Future<void> remove(String connectionId, String path) =>
      (_db.delete(_db.bookmarks)..where((b) => b.connectionId.equals(connectionId) & b.path.equals(path))).go();
}

final bookmarkRepositoryProvider = Provider((ref) => BookmarkRepository(ref.watch(appDatabaseProvider)));

final bookmarksProvider =
    StreamProvider.family<List<Bookmark>, String>((ref, connectionId) => ref.watch(bookmarkRepositoryProvider).watch(connectionId));
