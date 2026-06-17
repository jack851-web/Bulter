import 'package:drift/drift.dart';

/// 思想模块 — 读后感 / 写给自己的信 / 年度回顾。

@DataClassName('Thought')
class Thoughts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  TextColumn get source =>
      text()(); // 'book' | 'article' | 'movie' | 'conversation' | 'other'
  TextColumn get sourceRef => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get mood => integer().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Letter')
class Letters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get type => text()(); // 'to_self' | 'to_others' | 'to_future'
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get openedAt => dateTime().nullable()();
}

@DataClassName('AnnualReview')
class AnnualReviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get year => integer().unique()();
  TextColumn get content => text()();
  TextColumn get highlightsJson => text().withDefault(const Constant('[]'))();
  TextColumn get challengesJson => text().withDefault(const Constant('[]'))();
  TextColumn get lessons => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
