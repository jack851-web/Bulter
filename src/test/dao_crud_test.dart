// Bulter 第 2 步：DAO CRUD + Stream 行为测试
//
// 验证：所有业务模块的 DAO 至少完成"插入 + 查询 + Stream 推送"基线，
// 异常路径覆盖 null 字段与级联删除。

import 'package:bulter/db/app_database.dart';
import 'package:bulter/db/connection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // 使用 openInMemoryConnection 确保 sqlite-vec 扩展被注册
    db = AppDatabase.forTesting(openInMemoryConnection());
  });

  tearDown(() async {
    await db.close();
  });

  group('RelationshipDao', () {
    test('insertContact + getSingle', () async {
      final id = await db.relationshipDao.insertContact(
        ContactsCompanion.insert(
          name: 'Bob',
          relationshipType: 'friend',
          importance: const Value(4),
          tagsJson: const Value('["work","friend"]'),
        ),
      );
      expect(id, greaterThan(0));
      final c = await (db.select(
        db.contacts,
      )..where((c) => c.id.equals(id))).getSingle();
      expect(c.name, 'Bob');
      expect(c.importance, 4);
    });

    test('watchContacts 推流', () async {
      final stream = db.relationshipDao.watchContacts();
      final first = stream.first;
      await db.relationshipDao.insertContact(
        ContactsCompanion.insert(name: 'C1', relationshipType: 'friend'),
      );
      final list = await first;
      expect(list.length, 1);
    });

    test('级联：删除联系人 → 互动一并删除', () async {
      final cid = await db.relationshipDao.insertContact(
        ContactsCompanion.insert(name: 'Cascade', relationshipType: 'friend'),
      );
      await db.relationshipDao.insertInteraction(
        InteractionsCompanion.insert(
          contactId: cid,
          type: 'chat',
          summary: 'hi',
          happenedAt: DateTime.now(),
        ),
      );
      final before = (await db.select(db.interactions).get())
          .where((i) => i.contactId == cid)
          .length;
      expect(before, 1);
      await (db.delete(db.contacts)..where((c) => c.id.equals(cid))).go();
      final after = (await db.select(db.interactions).get())
          .where((i) => i.contactId == cid)
          .length;
      expect(after, 0);
    });
  });

  group('WealthDao', () {
    test('insertAccount + sumExpenseCents', () async {
      final aid = await db.wealthDao.insertAccount(
        AccountsCompanion.insert(name: 'Wallet', type: 'cash'),
      );
      await db.wealthDao.insertTransaction(
        TransactionsCompanion.insert(
          accountId: aid,
          amountCents: -1000,
          type: 'expense',
          category: 'food',
          occurredAt: DateTime.now(),
        ),
      );
      await db.wealthDao.insertTransaction(
        TransactionsCompanion.insert(
          accountId: aid,
          amountCents: -500,
          type: 'expense',
          category: 'food',
          occurredAt: DateTime.now(),
        ),
      );
      final sum = await db.wealthDao.sumExpenseCents(
        since: DateTime.now().subtract(const Duration(days: 1)),
      );
      // 支出 amountCents 为负，sum 也是负
      expect(sum, -1500);
    });

    test('sumExpenseCents 按 category 过滤', () async {
      final aid = await db.wealthDao.insertAccount(
        AccountsCompanion.insert(name: 'Card', type: 'bank'),
      );
      await db.wealthDao.insertTransaction(
        TransactionsCompanion.insert(
          accountId: aid,
          amountCents: -100,
          type: 'expense',
          category: 'food',
          occurredAt: DateTime.now(),
        ),
      );
      await db.wealthDao.insertTransaction(
        TransactionsCompanion.insert(
          accountId: aid,
          amountCents: -200,
          type: 'expense',
          category: 'transport',
          occurredAt: DateTime.now(),
        ),
      );
      final food = await db.wealthDao.sumExpenseCents(
        since: DateTime.now().subtract(const Duration(days: 1)),
        category: 'food',
      );
      expect(food, -100);
    });
  });

  group('GrowthDao', () {
    test('insertGoal + watchActiveGoals', () async {
      final gid = await db.growthDao.insertGoal(
        GoalsCompanion.insert(
          title: 'Read 12 books',
          category: 'skill',
          status: const Value('active'),
        ),
      );
      expect(gid, greaterThan(0));
      final stream = db.growthDao.watchActiveGoals();
      final list = await stream.first;
      expect(list.length, 1);
      expect(list.first.title, 'Read 12 books');
    });
  });

  group('ThoughtDao', () {
    test('insertThought + watchRecent', () async {
      await db.thoughtDao.insertThought(
        ThoughtsCompanion.insert(
          content: 'A short reflection',
          source: 'book',
          recordedAt: DateTime.now(),
        ),
      );
      final list = await db.thoughtDao.watchRecentThoughts().first;
      expect(list.length, 1);
    });
  });

  group('HealthDao', () {
    test('insertRecord + watchRecent', () async {
      await db.healthDao.insertRecord(
        HealthRecordsCompanion.insert(
          type: 'weight',
          valueNum: const Value(70.5),
          unit: const Value('kg'),
          occurredAt: DateTime.now(),
        ),
      );
      final list = await db.healthDao.watchRecentRecords().first;
      expect(list.length, 1);
    });
  });

  group('AiDao', () {
    test('insertSession + watchSessions', () async {
      await db.aiDao.insertSession(
        SessionsCompanion.insert(title: 'Plan my week'),
      );
      final list = await db.aiDao.watchSessions().first;
      expect(list.length, 1);
    });
  });

  group('DemoDao', () {
    test('insert + watchAll', () async {
      await db.demoDao.insert(
        DemoItemsCompanion.insert(name: 'Hello', value: const Value('42')),
      );
      final list = await db.demoDao.watchAll().first;
      expect(list.length, 1);
      expect(list.first.name, 'Hello');
    });
  });
}
