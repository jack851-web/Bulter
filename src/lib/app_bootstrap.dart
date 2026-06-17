import 'ai/sub_agents/sub_agent_registry.dart';
import 'ai/tools/tool_registry.dart';
import 'db/app_database.dart';
import 'db/backup.dart';
import 'db/connection.dart';
import 'modules/butler/butler_module.dart';
import 'modules/demo/demo_module.dart';
import 'modules/growth/growth_module.dart';
import 'modules/health/health_module.dart';
import 'modules/registry.dart';
import 'modules/relationship/relationship_module.dart';
import 'modules/thought/thought_module.dart';
import 'modules/wealth/wealth_module.dart';
import 'storage/storage_init.dart';

/// App 启动时调用一次：注册所有模块 + 同步子 Agent / 工具注册表。
///
/// **核心原则**：任何"加新模块"的动作只需要在下方 [registerAll] 加一行。
/// **不**修改 router / orchestrator / EventBus 等主框架文件。
///
/// [subdir] 用于指定 Hive / SQLite 子目录；测试场景下可传临时目录，
/// 避免 path_provider / 权限问题。
Future<void> bootstrapApp({String? subdir}) async {
  // 1. Hive 初始化（必须在 runApp 之前；模块按需懒打开自己的 Box）
  await initStorage(subdir: subdir);

  // 2. 数据库迁移：开库前先对比 schemaVersion。
  //    旧库先备份再迁移；新库直接 createAll。
  await _migrateDatabase(subdir: subdir);

  // 3. 注册所有模块 + 同步子 Agent / 工具注册表
  final registry = ModuleRegistry.instance;
  await registry.registerAll(const [
    // 中枢
    ButlerModule(),
    // 业务模块
    RelationshipModule(),
    GrowthModule(),
    WealthModule(),
    ThoughtModule(),
    HealthModule(),
    // 模块化验证假模块（plan.md 第 1 步完成标准第 8 条）
    DemoModule(),
  ]);

  // 主模型注册全量工具（含写工具）
  ToolRegistry.instance
    ..clear()
    ..registerFromModules(registry.all, includeWrite: true);

  // 子 Agent 注册表：每个子模型独立 ToolRegistry，物理隔离写工具
  SubAgentRegistry.instance
    ..clear()
    ..syncFromModuleRegistry();
}

/// 数据库迁移入口。
///
/// - 全新安装：直接 open，Drift 在 onCreate 阶段建表 + 建向量虚拟表。
/// - 升级安装：先调用 [BackupService.backupBeforeUpgrade] 备份，再让 Drift
///   走 [MigrationStrategy.onUpgrade]。任何迁移异常都会被 [BackupService.restoreFromBackup]
///   兜底（由调用方在 onUpgrade 内部 try/catch 后触发）。
Future<void> _migrateDatabase({String? subdir}) async {
  // 用 sqlite3 包直接读 user_version，不触发 Drift 的 onCreate / onUpgrade。
  final currentVersion = await readSqliteUserVersion(subdir: subdir);
  const targetVersion = 1; // 与 AppDatabase.schemaVersion 保持一致

  if (currentVersion > 0 && currentVersion < targetVersion) {
    final backupPath = await BackupService.backupBeforeUpgrade(
      fromVersion: currentVersion,
      toVersion: targetVersion,
      subdir: subdir,
    );
    assert(backupPath != null, '升级前备份必须生成');
  }
  // 真正打开数据库（触发 onCreate / onUpgrade）
  AppDatabase.I = AppDatabase(subdir: subdir);
  // 清理 7 天前的旧备份
  await BackupService.cleanExpired(subdir: subdir);
}
