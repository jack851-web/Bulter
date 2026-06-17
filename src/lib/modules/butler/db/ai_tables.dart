import 'package:drift/drift.dart';

/// Butler 中枢（AI）表：messages / sessions / briefings / memories / user_profile。
/// AI 记忆与会话、简报、用户画像等"跨模块"数据集中存放于本目录。

@DataClassName('Session')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get summary => text().nullable()();
  IntColumn get messageCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Message')
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // 'user' | 'assistant' | 'tool' | 'system'
  TextColumn get content => text()();
  TextColumn get toolCallsJson => text().nullable()();
  TextColumn get toolCallId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Briefing')
class Briefings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get moduleId => text()();
  DateTimeColumn get generatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get period =>
      text()(); // 'daily' | 'weekly' | 'monthly' | 'yearly'
  TextColumn get headline => text()();
  TextColumn get summary => text()();
  TextColumn get jsonData => text().withDefault(const Constant('{}'))();
  IntColumn get ttlSeconds => integer().withDefault(const Constant(86400))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Memory')
class Memories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type =>
      text()(); // 'fact' | 'event' | 'preference' | 'relationship'
  TextColumn get content => text()();
  IntColumn get sourceSessionId => integer().nullable()();
  RealColumn get confidence => real().withDefault(const Constant(1.0))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 用户画像：单行表（id 恒为 1）。启动时按需插入。
@DataClassName('UserProfile')
class UserProfiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get displayName => text().nullable()();
  TextColumn get occupation => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();
  TextColumn get preferencesJson => text().withDefault(const Constant('{}'))();
  TextColumn get goalsJson => text().withDefault(const Constant('[]'))();
  TextColumn get importantPeopleJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
