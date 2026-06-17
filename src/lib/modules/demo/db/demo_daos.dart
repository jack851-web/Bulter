import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'demo_tables.dart';

part 'demo_daos.g.dart';

@DriftAccessor(tables: [DemoItems])
class DemoDao extends DatabaseAccessor<AppDatabase> with _$DemoDaoMixin {
  DemoDao(super.db);

  Stream<List<DemoItem>> watchAll() =>
      (select(demoItems)..orderBy([
            (d) =>
                OrderingTerm(expression: d.createdAt, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<int> insert(DemoItemsCompanion d) => into(demoItems).insert(d);

  Future<int> deleteById(int id) =>
      (delete(demoItems)..where((d) => d.id.equals(id))).go();

  Future<int> count() async {
    final c = countAll();
    final row = await (selectOnly(demoItems)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }
}
