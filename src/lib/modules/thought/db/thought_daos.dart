import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'thought_tables.dart';

part 'thought_daos.g.dart';

@DriftAccessor(tables: [Thoughts, Letters, AnnualReviews])
class ThoughtDao extends DatabaseAccessor<AppDatabase> with _$ThoughtDaoMixin {
  ThoughtDao(super.db);

  Stream<List<Thought>> watchRecentThoughts({int limit = 50}) {
    return (select(thoughts)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.recordedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<int> insertThought(ThoughtsCompanion t) => into(thoughts).insert(t);
  Future<bool> updateThought(ThoughtsCompanion t) =>
      update(thoughts).replace(t);
  Future<int> deleteThought(int id) =>
      (delete(thoughts)..where((t) => t.id.equals(id))).go();

  Stream<List<Letter>> watchUnopenedLetters() {
    return (select(letters)
          ..where((l) => l.openedAt.isNull())
          ..orderBy([
            (l) =>
                OrderingTerm(expression: l.targetDate, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<int> insertLetter(LettersCompanion l) => into(letters).insert(l);
  Future<bool> updateLetter(LettersCompanion l) => update(letters).replace(l);
  Future<int> markLetterOpened(int id) =>
      (update(letters)..where((l) => l.id.equals(id)))
          .write(LettersCompanion(openedAt: Value(DateTime.now())))
          .then((_) => id);

  Future<List<AnnualReview>> allReviews() => select(annualReviews).get();
  Future<int> upsertAnnualReview(AnnualReviewsCompanion r) async {
    final existing = await (select(
      annualReviews,
    )..where((a) => a.year.equals(r.year.present as int))).getSingleOrNull();
    if (existing == null) {
      return into(annualReviews).insert(r);
    }
    return (update(annualReviews)..where((a) => a.id.equals(existing.id)))
        .write(r)
        .then((_) => existing.id);
  }
}
