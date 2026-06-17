import 'package:drift/drift.dart';

/// 健康模块 — 日常记录 / 体检报告 / 健康评分。

@DataClassName('HealthRecord')
class HealthRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type =>
      text()(); // 'weight' | 'sleep' | 'exercise' | 'symptom' | 'mood' | 'other'
  TextColumn get valueText => text().nullable()();
  RealColumn get valueNum => real().nullable()();
  TextColumn get unit => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('CheckupReport')
class CheckupReports extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get hospital => text()();
  DateTimeColumn get examDate => dateTime()();
  TextColumn get summary => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();
  TextColumn get itemsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('HealthScore')
class HealthScores extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get period => dateTime()();
  IntColumn get overallScore => integer()();
  TextColumn get dimensionsJson => text().withDefault(const Constant('{}'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
