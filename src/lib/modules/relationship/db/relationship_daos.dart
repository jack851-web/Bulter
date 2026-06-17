import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'relationship_tables.dart';

part 'relationship_daos.g.dart';

/// 关系模块 DAO 集合。
///
/// 所有 CRUD 集中于 [AppDatabase] 持有的 dao 子树，UI 与工具层只通过
/// `appDatabase.contactsDao / appDatabase.interactionsDao / appDatabase.favorsDao` 访问。
@DriftAccessor(tables: [Contacts, Interactions, Favors])
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
}
