import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'wealth_tables.dart';

part 'wealth_daos.g.dart';

@DriftAccessor(tables: [Accounts, Transactions, Budgets])
class WealthDao extends DatabaseAccessor<AppDatabase> with _$WealthDaoMixin {
  WealthDao(super.db);

  Stream<List<Account>> watchAccounts() => (select(
    accounts,
  )..orderBy([(a) => OrderingTerm(expression: a.createdAt)])).watch();

  Future<int> insertAccount(AccountsCompanion a) => into(accounts).insert(a);
  Future<bool> updateAccount(AccountsCompanion a) =>
      update(accounts).replace(a);
  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  Stream<List<Transaction>> watchRecentTransactions({int limit = 50}) {
    return (select(transactions)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<int> insertTransaction(TransactionsCompanion t) =>
      into(transactions).insert(t);

  Future<int> sumExpenseCents({required DateTime since, String? category}) {
    final sumExpr = transactions.amountCents.sum();
    final q = selectOnly(transactions)
      ..addColumns([sumExpr])
      ..where(
        transactions.occurredAt.isBiggerThanValue(since) &
            transactions.type.equals('expense'),
      );
    if (category != null) {
      q.where(transactions.category.equals(category));
    }
    return q.map<int>((row) => row.read<int>(sumExpr) ?? 0).getSingle();
  }

  Future<int> insertBudget(BudgetsCompanion b) => into(budgets).insert(b);
  Stream<List<Budget>> watchBudgets() => select(budgets).watch();
}
