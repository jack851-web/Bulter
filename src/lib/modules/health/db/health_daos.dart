import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'health_tables.dart';

part 'health_daos.g.dart';

@DriftAccessor(tables: [HealthRecords, CheckupReports, HealthScores])
class HealthDao extends DatabaseAccessor<AppDatabase> with _$HealthDaoMixin {
  HealthDao(super.db);

  Stream<List<HealthRecord>> watchRecentRecords({int limit = 50}) {
    return (select(healthRecords)
          ..orderBy([
            (h) =>
                OrderingTerm(expression: h.occurredAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<int> insertRecord(HealthRecordsCompanion r) =>
      into(healthRecords).insert(r);
  Future<bool> updateRecord(HealthRecordsCompanion r) =>
      update(healthRecords).replace(r);
  Future<int> deleteRecord(int id) =>
      (delete(healthRecords)..where((h) => h.id.equals(id))).go();

  Stream<List<CheckupReport>> watchReports() =>
      (select(checkupReports)..orderBy([
            (c) =>
                OrderingTerm(expression: c.examDate, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<int> insertReport(CheckupReportsCompanion r) =>
      into(checkupReports).insert(r);

  Stream<List<HealthScore>> watchScores() =>
      (select(healthScores)..orderBy([
            (s) => OrderingTerm(expression: s.period, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<int> insertScore(HealthScoresCompanion s) =>
      into(healthScores).insert(s);
}
