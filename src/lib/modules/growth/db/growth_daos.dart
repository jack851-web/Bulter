import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'growth_tables.dart';

part 'growth_daos.g.dart';

@DriftAccessor(tables: [Goals, Okrs, LearningRecords, Projects])
class GrowthDao extends DatabaseAccessor<AppDatabase> with _$GrowthDaoMixin {
  GrowthDao(super.db);

  // —— Goals ——
  Stream<List<Goal>> watchActiveGoals() {
    return (select(goals)
          ..where((g) => g.status.equals('active'))
          ..orderBy([
            (g) =>
                OrderingTerm(expression: g.targetDate, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<int> insertGoal(GoalsCompanion g) => into(goals).insert(g);
  Future<bool> updateGoal(GoalsCompanion g) => update(goals).replace(g);
  Future<int> deleteGoal(int id) =>
      (delete(goals)..where((g) => g.id.equals(id))).go();

  // —— OKRs ——
  Stream<List<Okr>> watchOkrs() => select(okrs).watch();
  Future<int> insertOkr(OkrsCompanion o) => into(okrs).insert(o);

  // —— Learning ——
  Stream<List<LearningRecord>> watchLearning() {
    return (select(learningRecords)..orderBy([
          (l) => OrderingTerm(expression: l.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<int> insertLearning(LearningRecordsCompanion l) =>
      into(learningRecords).insert(l);
  Future<bool> updateLearning(LearningRecordsCompanion l) =>
      update(learningRecords).replace(l);
  Future<int> deleteLearning(int id) =>
      (delete(learningRecords)..where((l) => l.id.equals(id))).go();

  // —— Projects ——
  Stream<List<Project>> watchProjects() {
    return (select(projects)..orderBy([
          (p) => OrderingTerm(expression: p.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<int> insertProject(ProjectsCompanion p) => into(projects).insert(p);
}
