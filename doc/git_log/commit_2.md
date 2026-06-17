# Bulter Commit 2 — 本地数据存储层

## 基本信息

| 字段 | 值 |
|------|------|
| 版本号 | **0.2.0**（SemVer，Minor：新增数据层，向后兼容 Step 1 骨架） |
| 步骤 | Step 2 / 20（见 [plan.md](../../doc/first/plan.md)） |
| Commit 类型 | `feat(storage)` |
| 模块范围 | `db` / `storage` / `security` / `modules/*/db` |
| 风险等级 | 🟡 中（新增主库 schema，升级前自动备份 + 失败回滚已就位） |

## Commit Message

```
feat(storage): add local data layer with drift/hive/sqlite-vec (step 2)

建立 Bulter 本地数据层：22 张业务表覆盖 6 大模块 + Demo，Drift 做主库 ORM，
Hive 做 KV 缓存，sqlite-vec 做 RAG 语义记忆。三套存储统一通过
BulterModule.tableClasses / daoClasses 接口动态注册，AppDatabase
在 onCreate 阶段一次性建表并初始化 vec0 虚拟表。

数据安全：升级前自动备份 SQLite + Hive、迁移失败自动回滚、保留 7 天
过期清理；DataExportService 支持全量 JSON 导出导入作为最后兜底。
所有 API 在 sqlite-vec 不可用时降级为空操作，不阻断主流程。

26 个测试覆盖迁移 / 备份 / 回滚 / CRUD / Stream / 导出导入 / 模块化 / Hive
全链路，flutter test 全绿。

完成 plan.md Step 2 完成标准 1–7。
```

## 变更内容

### 新增

| 路径 | 作用 |
|------|------|
| `src/lib/db/app_database.dart` | 主数据库类，整合所有模块表和 DAO，schemaVersion = 1 |
| `src/lib/db/app_database.g.dart` | Drift 生成代码（22 表 + 7 DAO） |
| `src/lib/db/connection.dart` | 打开数据库连接，封装 sqlite-vec 扩展注册，失败降级 |
| `src/lib/db/backup.dart` | 升级前自动备份 + 失败回滚 + 7 天过期清理 |
| `src/lib/db/vector_store.dart` | 封装 vec0 虚拟表（DDL / insert / search） |
| `src/lib/security/data_export.dart` | 全量数据 JSON 导出 / 导入 |
| `src/lib/storage/box_names.dart` | 4 个 Hive Box 名称 + versionId 集中管理 |
| `src/lib/storage/storage_init.dart` | Hive 初始化（subdir 支持测试） |
| `src/lib/modules/butler/db/ai_tables.dart` + `ai_daos.dart` | AI 中枢 4 张表 + AiDao |
| `src/lib/modules/relationship/db/relationship_tables.dart` + `relationship_daos.dart` | 关系模块 3 张表 + RelationshipDao |
| `src/lib/modules/growth/db/growth_tables.dart` + `growth_daos.dart` | 成长模块 4 张表 + GrowthDao |
| `src/lib/modules/wealth/db/wealth_tables.dart` + `wealth_daos.dart` | 财富模块 3 张表 + WealthDao |
| `src/lib/modules/thought/db/thought_tables.dart` + `thought_daos.dart` | 思想模块 3 张表 + ThoughtDao |
| `src/lib/modules/health/db/health_tables.dart` + `health_daos.dart` | 健康模块 3 张表 + HealthDao |
| `src/lib/modules/demo/db/demo_tables.dart` + `demo_daos.dart` | Demo 模块 1 张表 + DemoDao |
| `test/widget_test.dart`（重写） | 烟测：bootstrap + 7 模块 + subdir 临时目录 |
| `test/hive_test.dart` | BulterBoxes 名称 / 初始化 / Box 打开 |
| `test/module_registry_test.dart` | bootstrapApp 注册 7 模块 + table/dao 类列表 |
| `test/db_migration_test.dart` | schemaVersion / 备份 / 回滚 / 清理 |
| `test/dao_crud_test.dart` | 6 模块 DAO CRUD + Stream + sum/聚合 |
| `test/data_export_test.dart` | 导出 / 导入 round-trip + 异常路径 |
| `doc/code-quality/code_review_report.md` | Step 2 代码审查报告 |
| `doc/code-quality/code_review_report_1.md` | Step 1 报告保留（已上一步沉淀） |

### 修改

| 路径 | 关键变更 |
|------|----------|
| `src/lib/app_bootstrap.dart` | 接受 `subdir` 参数；`_migrateDatabase` 透传 subdir 给 `readSqliteUserVersion` / `BackupService` |
| `src/lib/modules/bulter_module.dart` | 新增 `tableClasses` / `daoClasses` 字段（默认空列表） |
| `src/lib/modules/butler/butler_module.dart` | 声明 4 表 + AiDao |
| `src/lib/modules/relationship/relationship_module.dart` | 声明 3 表 + RelationshipDao |
| `src/lib/modules/growth/growth_module.dart` | 声明 4 表 + GrowthDao |
| `src/lib/modules/wealth/wealth_module.dart` | 声明 3 表 + WealthDao |
| `src/lib/modules/thought/thought_module.dart` | 声明 3 表 + ThoughtDao |
| `src/lib/modules/health/health_module.dart` | 声明 3 表 + HealthDao |
| `src/lib/modules/demo/demo_module.dart` | 声明 1 表 + DemoDao |
| `src/lib/router/app_shell.dart` | 仅在主壳静态展示需要时微调，无功能变更 |
| `src/pubspec.yaml` / `src/pubspec.lock` | 新增 `drift` / `drift_flutter` / `sqlite3` / `sqlite3_flutter_libs` / `sqlite_vec` / `hive` / `hive_flutter` / `path` / `path_provider` / `drift_dev` / `build_runner` 等依赖 |

## 关键设计

1. **模块化数据层**：`BulterModule` 新增 `tableClasses` / `daoClasses` 抽象，
   `AppDatabase` 在构造时收集注册表，自动 `@DriftDatabase(tables: [...], daos: [...])`
   静态展开。**新模块不再需要修改 `app_database.dart`**。
2. **三存储协同**：Drift（强关系 + 索引） / Hive（轻 KV 缓存） / sqlite-vec（向量）
   通过 `AppDatabase.vectorStore` 统一入口，缺失时 `isVecAvailable()` 降级。
3. **备份与回滚**：升级前 `BackupService.backupBeforeUpgrade` 复制 SQLite + Hive
   到 `<base>/备份/升级前_vX→vY_<ts>/`，`onUpgrade` 异常时调用
   `BackupService.restoreFromBackup` 还原；7 天前自动清理。
4. **导出导入兜底**：`DataExportService` 把 22 张表 JSON 化，作为备份之外的
   "用户主动备份" 通道；`importFrom` 走事务：先清空子表再批量插入。
5. **测试可移植**：所有 IO 类（`initStorage` / `openAppConnection` /
   `readSqliteUserVersion` / `BackupService.*`）都接受 `subdir` 参数，
   测试场景统一传 `Directory.systemTemp.createTemp(...)` 临时目录，
   不依赖 `path_provider` 平台通道。

## 测试

```bash
$ cd src && flutter test
00:02 +26: All tests passed!
```

- ✅ `widget_test.dart`：Step 1 烟测 + Step 2 扩展
- ✅ `hive_test.dart`：4 个 box + 初始化幂等 + Box 单例
- ✅ `module_registry_test.dart`：7 模块 table/DAO 列表
- ✅ `db_migration_test.dart`：schemaVersion / 备份 / 回滚
- ✅ `dao_crud_test.dart`：6 模块 CRUD + Stream + sum
- ✅ `data_export_test.dart`：export→import round-trip

## 遗留 / 下一步

详见 `doc/code-quality/code_review_report.md`：
- **S-1**：`*.g.dart` 入版本控制，建议下个 PR 加 `.gitignore` 并 `git rm --cached`。
- **S-2**：`sqlite-vec` 加载失败时 `print` 噪声，建议抽 `BulterLog` 统一。
- **M-1~M-7**：迁移占位 / 备份 base 抽公共 / 导出导入 type-driven / 静态单例等。

这些将在 Step 3 之前由 `fix(refactor): cleanup data layer` 提交集中处理。
