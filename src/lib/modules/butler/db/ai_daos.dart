import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import 'ai_tables.dart';

part 'ai_daos.g.dart';

/// Butler（AI）模块 DAO 集合。
@DriftAccessor(tables: [Sessions, Messages, Briefings, Memories, UserProfiles])
class AiDao extends DatabaseAccessor<AppDatabase> with _$AiDaoMixin {
  AiDao(super.db);

  // —— Sessions ——
  Stream<List<Session>> watchSessions() {
    return (select(sessions)..orderBy([
          (s) => OrderingTerm(expression: s.startedAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<int> insertSession(SessionsCompanion s) => into(sessions).insert(s);
  Future<int> deleteSession(int id) =>
      (delete(sessions)..where((s) => s.id.equals(id))).go();

  // —— Messages ——
  Stream<List<Message>> watchMessagesFor(int sessionId) {
    return (select(messages)
          ..where((m) => m.sessionId.equals(sessionId))
          ..orderBy([
            (m) =>
                OrderingTerm(expression: m.createdAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<int> insertMessage(MessagesCompanion m) => into(messages).insert(m);

  // —— Briefings ——
  Future<Briefing?> latestBriefingFor(String moduleId) {
    return (select(briefings)
          ..where((b) => b.moduleId.equals(moduleId))
          ..orderBy([
            (b) => OrderingTerm(
              expression: b.generatedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> insertBriefing(BriefingsCompanion b) => into(briefings).insert(b);

  Stream<List<Briefing>> watchBriefingsFor(String moduleId) {
    return (select(briefings)
          ..where((b) => b.moduleId.equals(moduleId))
          ..orderBy([
            (b) => OrderingTerm(
              expression: b.generatedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  // —— Memories ——
  Future<int> insertMemory(MemoriesCompanion m) => into(memories).insert(m);
  Future<int> deleteMemory(int id) =>
      (delete(memories)..where((m) => m.id.equals(id))).go();
  Stream<List<Memory>> watchMemories() {
    return (select(memories)..orderBy([
          (m) => OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // —— User Profile (单行) ——
  Future<UserProfile?> getProfile() =>
      (select(userProfiles)..where((u) => u.id.equals(1))).getSingleOrNull();

  Future<void> upsertProfile(UserProfilesCompanion p) async {
    final existing = await getProfile();
    if (existing == null) {
      await into(userProfiles).insert(p);
    } else {
      await (update(userProfiles)..where((u) => u.id.equals(1))).write(p);
    }
  }
}
