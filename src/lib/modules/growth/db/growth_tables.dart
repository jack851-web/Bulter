import 'package:drift/drift.dart';

/// 成长模块 — 目标 / OKR / 学习记录 / 项目。
///
/// DAO 实现见 [growth_daos.dart]。

@DataClassName('Goal')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text()(); // 'career' | 'skill' | 'health' | ...
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // active | completed | abandoned
  IntColumn get progress => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Okr')
class Okrs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().nullable().references(
    Goals,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get objective => text()();
  TextColumn get keyResultsJson => text().withDefault(const Constant('[]'))();
  TextColumn get period =>
      text()(); // 'Q1' | 'Q2' | 'Q3' | 'Q4' | 'year' | custom
  IntColumn get progress => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('LearningRecord')
class LearningRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get source => text()(); // 'book' | 'course' | 'article' | 'video'
  TextColumn get author => text().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get rating => integer().nullable()(); // 1-5
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Project')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('planning'),
  )(); // planning | ongoing | done | archived
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get relatedRecordsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
