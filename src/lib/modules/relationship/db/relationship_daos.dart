import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'relationship_tables.dart';

part 'relationship_daos.g.dart';

/// 关系模块 DAO 集合。
///
/// 所有 CRUD 集中于 [AppDatabase] 持有的 dao 子树，UI 与工具层只通过
/// `appDatabase.contactsDao / appDatabase.interactionsDao / appDatabase.favorsDao` 访问。
@DriftAccessor(tables: [Contacts, Interactions, Favors, Promises])
class RelationshipDao extends DatabaseAccessor<AppDatabase>
    with _$RelationshipDaoMixin {
  RelationshipDao(super.db);

  // —— Contacts ——
  Stream<List<Contact>> watchContacts({bool includeArchived = false}) {
    final q = includeArchived
        ? select(contacts)
        : (select(contacts)..where((c) => c.isArchived.equals(false)));
    q.orderBy([
      (c) => OrderingTerm(expression: c.updatedAt, mode: OrderingMode.desc),
    ]);
    return q.watch();
  }

  Future<int> insertContact(ContactsCompanion c) => into(contacts).insert(c);

  Future<bool> updateContact(ContactsCompanion c) =>
      update(contacts).replace(c);

  Future<int> deleteContact(int id) =>
      (delete(contacts)..where((c) => c.id.equals(id))).go();

  Future<Contact?> getContact(int id) =>
      (select(contacts)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<Contact?> watchContact(int id) =>
      (select(contacts)..where((c) => c.id.equals(id))).watchSingleOrNull();

  // —— Interactions ——
  Stream<List<Interaction>> watchInteractionsFor(int contactId) {
    return (select(interactions)
          ..where((i) => i.contactId.equals(contactId))
          ..orderBy([
            (i) =>
                OrderingTerm(expression: i.happenedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 全量互动流（用于主页"距上次联系天数"统计）。
  Stream<List<Interaction>> watchAllInteractions() {
    return (select(interactions)..orderBy([
          (i) =>
              OrderingTerm(expression: i.happenedAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<int> insertInteraction(InteractionsCompanion i) =>
      into(interactions).insert(i);

  Future<int> deleteInteraction(int id) =>
      (delete(interactions)..where((i) => i.id.equals(id))).go();

  // —— Favors ——
  Stream<List<Favor>> watchOpenFavors() {
    return (select(favors)
          ..where((f) => f.status.equals('open'))
          ..orderBy([
            (f) =>
                OrderingTerm(expression: f.happenedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<int> insertFavor(FavorsCompanion f) => into(favors).insert(f);
  Future<int> closeFavor(int id) =>
      (update(favors)..where((f) => f.id.equals(id)))
          .write(
            const FavorsCompanion(
              status: Value('closed'),
              closedAt: Value.absent(),
            ),
          )
          .then((_) => id);
  Future<int> deleteFavor(int id) =>
      (delete(favors)..where((f) => f.id.equals(id))).go();

  // —— Promises（Step 13）——

  Future<int> insertPromise(PromisesCompanion p) => into(promises).insert(p);
  Future<bool> updatePromise(PromisesCompanion p) =>
      update(promises).replace(p);
  Future<int> deletePromise(int id) =>
      (delete(promises)..where((p) => p.id.equals(id))).go();

  /// 待办约定（未完成、未取消）。
  Stream<List<Promise>> watchPendingPromises() {
    return (select(promises)
          ..where((p) => p.status.equals('pending'))
          ..orderBy([(p) => OrderingTerm(expression: p.dueAt)]))
        .watch();
  }

  /// 即将到期（未来 [window] 内的约定，用于提醒）。
  Future<List<Promise>> promisesDueSoon({
    Duration window = const Duration(hours: 24),
  }) async {
    final now = DateTime.now();
    final end = now.add(window);
    return (select(promises)
          ..where(
            (p) =>
                p.status.equals('pending') & p.dueAt.isBetweenValues(now, end),
          )
          ..orderBy([(p) => OrderingTerm(expression: p.dueAt)]))
        .get();
  }

  /// 标记某约定为已提醒（避免重复推送）。
  Future<int> markPromisedAsReminded(int id) =>
      (update(promises)..where((p) => p.id.equals(id)))
          .write(const PromisesCompanion(reminded: Value(true)))
          .then((v) => id);

  /// 完成约定。
  Future<int> fulfillPromise(int id) =>
      (update(promises)..where((p) => p.id.equals(id)))
          .write(
            PromisesCompanion(
              status: const Value('fulfilled'),
              fulfilledAt: Value(DateTime.now()),
            ),
          )
          .then((_) => id);
}
