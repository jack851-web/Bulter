import 'package:drift/drift.dart';

import '../features/screenshot/db/screenshot_dao.dart';
import '../features/screenshot/db/screenshot_tables.dart';
import '../modules/butler/db/ai_daos.dart';
import '../modules/butler/db/ai_tables.dart';
import '../modules/demo/db/demo_daos.dart';
import '../modules/demo/db/demo_tables.dart';
import '../modules/growth/db/growth_daos.dart';
import '../modules/growth/db/growth_tables.dart';
import '../modules/health/db/health_daos.dart';
import '../modules/health/db/health_tables.dart';
import '../modules/relationship/db/relationship_daos.dart';
import '../modules/relationship/db/relationship_tables.dart';
import '../modules/thought/db/thought_daos.dart';
import '../modules/thought/db/thought_tables.dart';
import '../modules/wealth/db/wealth_daos.dart';
import '../modules/wealth/db/wealth_tables.dart';
import 'vector_store.dart';
import 'connection.dart';

part 'app_database.g.dart';

/// Bulter 主数据库。
///
/// **schemaVersion 规则**：
/// - 主库 `schemaVersion` 每次表结构变更 +1。
/// - 向量库（[VectorStore]）单独 `vectorSchemaVersion`，独立升级。
/// - onUpgrade 按 from→to 步进式迁移，**绝不 drop 重建**。
/// - 升级前自动调用 [BackupService] 备份。
@DriftDatabase(
  tables: [
    // 关系模块
    Contacts,
    Interactions,
    Favors,
    // 成长模块
    Goals,
    Okrs,
    LearningRecords,
    Projects,
    // 财富模块
    Accounts,
    Transactions,
    Budgets,
    // 思想模块
    Thoughts,
    Letters,
    AnnualReviews,
    // 健康模块
    HealthRecords,
    CheckupReports,
    HealthScores,
    // Butler (AI)
    Sessions,
    Messages,
    Briefings,
    Memories,
    UserProfiles,
    // Step 9 + Step 10 截图
    Screenshots,
    // Demo 模块（模块化验证）
    DemoItems,
  ],
  daos: [
    RelationshipDao,
    GrowthDao,
    WealthDao,
    ThoughtDao,
    HealthDao,
    AiDao,
    ScreenshotDao,
    DemoDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? subdir, QueryExecutor? executor})
    : super(executor ?? openAppConnection(subdir: subdir));

  /// 内部构造：测试场景用 in-memory。
  AppDatabase.forTesting(super.executor);

  /// 全局单例（在 [bootstrapApp] 中赋值）。
  /// 业务代码通过 `AppDatabase.I.xxxDao` 访问；测试代码用 [forTesting] 自行 new。
  static AppDatabase? _instance;
  static AppDatabase get I {
    final v = _instance;
    if (v == null) {
      throw StateError('AppDatabase 尚未初始化，请先调用 bootstrapApp()');
    }
    return v;
  }

  static set I(AppDatabase value) => _instance = value;

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // 初始化向量虚拟表（独立 DDL）
      await VectorStore(this).ensureTable();
    },
    onUpgrade: (m, from, to) async {
      // Step 9 + Step 10：v1 → v3 一次性加 screenshots 表（含 autoSinkStatus 字段）
      // 老用户数据库没有 screenshots 表——一次性 createTable 会包含全部字段
      if (from < 3) {
        await m.createTable(screenshots);
      }
    },
    beforeOpen: (details) async {
      // 启用外键约束（Drift 默认未开启）
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 向量库（独立 DDL，独立 schemaVersion）。
  late final VectorStore vectorStore = VectorStore(this);
}
