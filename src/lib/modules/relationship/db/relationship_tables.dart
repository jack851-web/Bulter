import 'package:drift/drift.dart';

/// 关系模块 — 联系人 / 互动 / 人情债。
///
/// 表结构定义集中于此文件，便于 [AppDatabase] 静态注册。
/// DAO 实现在 [relationship_daos.dart]。

/// 联系人主表。tags 用 JSON 文本存储，importance 0-10。
@DataClassName('Contact')
class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nickname => text().nullable()();
  TextColumn get relationshipType =>
      text()(); // 'friend' | 'family' | 'colleague' | ...
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();
  DateTimeColumn get lastContactAt => dateTime().nullable()();
  IntColumn get importance => integer().withDefault(const Constant(5))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 互动记录：通话、消息、见面等。每次互动都挂在一个 contact 下。
@DataClassName('Interaction')
class Interactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get happenedAt => dateTime()();
  TextColumn get type => text()(); // 'call' | 'message' | 'meeting' | ...
  TextColumn get summary => text()();
  IntColumn get mood => integer().nullable()(); // 1-5
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 人情债：借/还/送/收。amount 单位：分。
@DataClassName('Favor')
class Favors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get direction =>
      text()(); // 'i_owe' | 'they_owe' | 'gift_given' | 'gift_received'
  TextColumn get description => text()();
  IntColumn get amountCents => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get happenedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
