import 'package:drift/drift.dart';

/// 财富模块 — 账户 / 交易 / 预算。
/// 金额一律以"分"（IntColumn）存储，避免浮点误差。

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type =>
      text()(); // 'cash' | 'bank' | 'credit' | 'investment' | 'other'
  IntColumn get balanceCents => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Transaction')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountCents => integer()(); // 正数=收入，负数=支出
  TextColumn get type => text()(); // 'income' | 'expense' | 'transfer'
  TextColumn get category => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get description => text().nullable()();
  IntColumn get relatedContactId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  TextColumn get period => text()(); // 'monthly' | 'weekly' | 'yearly'
  IntColumn get limitCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
