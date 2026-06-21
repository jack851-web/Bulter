import 'ai/ai_service.dart';
import 'ai/briefing/briefing_scheduler.dart';
import 'ai/briefing/briefing_store.dart';
import 'ai/memory/long_term.dart';
import 'ai/memory/memory_manager.dart';
import 'ai/memory/user_profile.dart';
import 'ai/model_registry.dart';
import 'ai/rag/context_injector.dart';
import 'ai/rag/embedder.dart';
import 'ai/rag/retriever.dart';
import 'ai/sub_agents/sub_agent_registry.dart';
import 'ai/tools/bulter_tools_bootstrap.dart';
import 'ai/tools/tool_registry.dart';
import 'db/app_database.dart';
import 'db/backup.dart';
import 'db/connection.dart';
import 'db/vector_store.dart';
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

  // 1.5 加载 AI 模型配置（用户当前选择 + 各 vendor 的 API Key）
  await ModelRegistry.instance.load();

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

  // 把模块声明的工具替换为含执行器的实现（通过 BulterToolsBootstrap）
  // 这一步**不**重置已注册的 schema-only 工具定义；它仅补齐 executor。
  BulterToolsBootstrap.registerAll(ToolRegistry.instance, AppDatabase.I);

  // 子 Agent 注册表：每个子模型独立 ToolRegistry，物理隔离写工具
  SubAgentRegistry.instance
    ..clear()
    ..syncFromModuleRegistry();

  // 同样为每个子 Agent 的隔离注册表补齐 executor
  for (final entry in SubAgentRegistry.instance.allToolRegistries.entries) {
    BulterToolsBootstrap.registerAll(entry.value, AppDatabase.I);
  }

  // 4. RAG / 长期记忆 初始化
  await _initRag();

  // 5. 简报系统初始化（Step 9）：先打开 Hive Box + 从 Drift 加载缓存，再启动调度器
  await BriefingStore.instance.init();
  BriefingScheduler.instance.start();
}

/// 初始化 RAG 子系统（Step 6）。
///
/// 顺序：
/// 1. 解析 Embedder（OpenAI 兼容 / LocalHash）
/// 2. 用 Embedder 的维度建（或迁移）sqlite-vec 虚拟表
/// 3. 构造 Retriever + ContextInjector + LongTermMemory
/// 4. 绑给 AiService.streamCompletion
Future<void> _initRag() async {
  final db = AppDatabase.I;
  final embedder = EmbedderFactory.resolve();

  // 1) 确保 vec_embeddings 表存在 / 维度匹配
  await db.vectorStore.ensureTable(dimensions: embedder.dimensions);

  // 2) 构造检索 + 注入
  final retriever = Retriever(embedder: embedder, store: db.vectorStore);
  final injector = ContextInjector(retriever: retriever);

  // 3) 长期记忆
  final longTerm = LongTermMemory(
    db: db,
    embedder: embedder,
    retriever: retriever,
    aiService: AiService.instance,
  );

  // 4) 用户画像（Step 7）
  final profile = UserProfileMemory(db: db, aiService: AiService.instance);

  // 5) 4 层记忆统一管理器（Step 7）
  final memory = MemoryManager(
    db: db,
    embedder: embedder,
    retriever: retriever,
    injector: injector,
    longTerm: longTerm,
    userProfile: profile,
    aiService: AiService.instance,
  );

  // 6) 绑给 AI 服务
  AiService.bindRag(
    RagBundle(injector: injector, longTerm: longTerm, memory: memory),
  );
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
  // 把 DB 绑给 AiService（用于 delete_* 二次确认）
  AiService.bindDatabase(AppDatabase.I);
}
