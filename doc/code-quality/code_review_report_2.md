# Bulter 项目代码审查报告（Step 2）

> **审查范围**：`d:\others\app\Bulter\src\lib` 中 Step 2 期间新增 / 变更的全部源码
> （`lib/db/`、`lib/security/data_export.dart`、`lib/storage/`、各模块 `db/` 子包、`lib/app_bootstrap.dart`、
> `lib/modules/bulter_module.dart`、各模块 `*_module.dart`、模块化 `*_daos.dart`）+
> `test/` 下 7 个测试文件 + `pubspec.yaml` / `pubspec.lock`。
> **审查基线**：`doc/first/plan.md` 第 2 步「本地数据存储层」完成标准 1–8。
> **审查日期**：2026-06-17。
> **审查维度**：语法、逻辑、Drift 用法、模块化、迁移/备份、可测性、安全、规范。

---

## 一、整体评价

**总体评价：良好，Step 2 数据层与模块化骨架已可运行；26 个测试全部通过。**

Step 2 完整落库了 22 张业务表 + 7 个 DAO、Drift / Hive / sqlite-vec 三套存储、备份回滚 + 导出导入兜底，模块化接口（`tableClasses` / `daoClasses`）让 Demo 与 6 大业务模块可一致注册。修复了 Step 1 留下的若干动态分发问题（DAO 基类统一为 `DatabaseAccessor<AppDatabase>`、表名实际化、`isNotNull` 冲突、`expense` 预期值等）。

但仍存在 **2 个严重缺陷**（Drift 派生文件入版本控制、向量扩展加载在桌面测试环境的 `print` 噪声）和 **多个一般问题**（`reset` 后备回退、备份拷贝串行化、迁移策略占位为空等），建议在 Step 3 之前修复严重缺陷与一般问题，避免后续 AI 层叠加更多逻辑后修复成本上升。

| 严重 | 一般 | 优化建议 | 合计 |
|------|------|----------|------|
| 2    | 7    | 5        | 14  |

---

## 二、严重问题（必须修复）

### S-1：`*.g.dart` / `*.freezed.dart` 派生文件入版本控制

- **文件**：`src/lib/db/app_database.g.dart`（10 776 行）以及各模块 `db/*_daos.g.dart`。
- **位置**：仓库根目录已跟踪这些文件。
- **根因**：Step 2 直接 `git add` 了 `flutter pub run build_runner build` 的生成产物。
- **风险**：
  1. PR diff 噪音极大，审查者难以聚焦真实逻辑改动；
  2. 生成代码与 `.dart_tool/` 缓存不一致时会引发编译失败；
  3. 后续 Step 增删表字段时，开发者很容易忘记重跑 build_runner，导致 `app_database.g.dart` 与 table 定义脱节。
- **修改建议**：
  1. 在 `src/.gitignore` 增加 `lib/**/*.g.dart` 与 `lib/**/*.freezed.dart`；
  2. 仓库根目录增加 `.gitattributes` 标注 `*.g.dart linguist-generated=true`；
  3. 在 `src/pubspec.yaml` 注释里加 `// run: dart run build_runner build --delete-conflicting-outputs`；
  4. 当前已跟踪的派生文件从仓库删除（`git rm --cached src/lib/db/app_database.g.dart ...`），保留本地副本供 IDE 跳转。

### S-2：sqlite-vec 桌面测试环境加载失败时 `print` 噪声

- **文件**：`src/lib/db/connection.dart:23-31`、`src/lib/db/vector_store.dart:30-37`。
- **根因**：
  1. `_ensureVecExtensionRegistered` 在 `print('[Bulter] sqlite-vec 扩展加载失败...')`；
  2. `VectorStore.ensureTable` 在 `print('[VectorStore] ensureTable skipped: ...')`；
  3. 这两条分支是 **测试 / 桌面** 期望走过的正常路径（vec0 动态库在 Windows 测试环境确实没装），但目前直接 stdout 喷出，污染 CI 日志并干扰错误识别。
- **风险**：CI / `flutter test` 跑出来的日志很难找到真正的失败用例；同时也违反 `analysis_options.yaml` 推荐的 `avoid_print`。
- **修改建议**：
  1. 将 `print` 替换为 `debugPrint`（测试环境静默），或仅在 `kDebugMode` 下输出；
  2. 增加 `BulterLog.warn(...)` / `BulterLog.info(...)` 统一抽象；
  3. 在 `analysis_options.yaml` 添加 `avoid_print: true`，CI 加 `dart fix --apply` / `flutter analyze --fatal-infos`。

---

## 三、一般问题（应修复）

### M-1：DAO 基类泛型早期被写为 `DatabaseAccessor<GeneratedDatabase>`

- **文件**：`src/lib/modules/*/db/*_daos.dart`（7 个文件）。
- **根因**：Step 2 早期代码继承了 Drift 默认的 `GeneratedDatabase`，导致 `_$AppDatabase` 生成代码无法把 DAO 接到主库上，需要切到 `DatabaseAccessor<AppDatabase>` 才能拿到 `contacts` / `transactions` 等表。
- **修复结果**：当前已统一改为 `DatabaseAccessor<AppDatabase>`，并 `import 'package:bulter/db/app_database.dart'`。
- **遗留风险**：`AppDatabase` 与模块 DAO 形成**循环依赖**（DAO → AppDatabase → DriftDatabase 收集 → DAO 列表）。后续 Step 引入的 `@DriftAccessor` 抽象可能再踩坑。
- **建议**：
  1. 在 `app_database.dart` 注释里写明「DAO 泛型必须为 `AppDatabase`，不允许 `GeneratedDatabase`」；
  2. 加一个 `test/dao_base_type_test.dart`，用反射断言 `RelationshipDao` 等 7 个 DAO 的 `attachedDatabase.runtimeType == AppDatabase`。

### M-2：迁移策略 `onUpgrade` 占位为空

- **文件**：`src/lib/db/app_database.dart:91-94`。
- **根因**：`onUpgrade: (m, from, to) async {}`，没有 schema 步进示例。
- **风险**：Step 3 真正修改表结构时，新人不知道该写 `if (from < 2) { await m.addColumn(...) }` 还是 `m.createTable(newTable)`。
- **建议**：
  1. 在 `onUpgrade` 里加注释模板（`// Example: if (from < 2) { await m.addColumn(contacts, contacts.email); }`）；
  2. 写一个 `test/migration_strategy_test.dart`，临时把 schemaVersion 改成 2，断言能从空库升上来。

### M-3：备份 / 回滚 / 清理走 `getApplicationDocumentsDirectory()` 默认路径，无统一 base 解析

- **文件**：`src/lib/db/backup.dart:13-95`。
- **根因**：原本直接 `getApplicationDocumentsDirectory()`，无法让测试场景落到临时目录。已通过 `_resolveBase(subdir: ...)` 抽出来解决。
- **遗留**：`backup.dart` 与 `connection.dart` 中「base 目录」概念重复，且文档里没说明「Hive 目录和 SQLite 必须同根」。
- **建议**：
  1. 抽出 `lib/storage/app_paths.dart` 统一持有 `appBaseDir(subdir)`，所有 IO 入口都走它；
  2. 在 `lib/app_bootstrap.dart` 启动时 `final appBase = await AppPaths.resolve(subdir);` 一次，下游全部传 `appBase`。

### M-4：`DataExportService._tableNames` 与 Drift class 名称紧耦合

- **文件**：`src/lib/security/data_export.dart:16-43`。
- **根因**：手写 class→SQL 表名映射表，新模块 / 改表名时容易漏改。
- **风险**：Step 3 增加新表 / 改名后，`_tableNames` 不更新会导致 `importFrom` 静默丢失数据。
- **建议**：
  1. 通过 `db.allTables`（Drift 暴露的 `_$AppDatabase` 内部 `Table` 列表）反射 `actualTableName`；
  2. 或者 `static const _tableNames = <Type, String>{Contacts: 'contacts', ...}` 改成「类型驱动」；
  3. 写一个 round-trip 测试：导出→清空→导入，断言每张表行数一致（已存在 `data_export_test.dart`，可补 `rowCount` 断言）。

### M-5：测试用例中 `AppDatabase.forTesting` 与 `bootstrapApp` 共用静态单例

- **文件**：`src/test/module_registry_test.dart` / `src/test/widget_test.dart`。
- **根因**：`bootstrapApp` 会把 `AppDatabase.I` 赋值为真实数据库实例。`module_registry_test` 和 `widget_test` 同时运行时会触发 drift 的 "database class created multiple times" warning（虽然不会失败但每次跑都会喷）。
- **建议**：
  1. 在 `AppDatabase.I` setter 之前先 `await _instance?.close()`，再赋新值；
  2. 或者在 `tearDown` 中 `AppDatabase.I = null`；
  3. 加测试 `expect(registry.isInitialized, true)` 时同时断言 `AppDatabase.I != null`，并清掉。

### M-6：`openAppConnection` 与 `readSqliteUserVersion` 都假设根目录可写

- **文件**：`src/lib/db/connection.dart:39-53` 与 `78-86`。
- **根因**：`subdir` 不存在时未 `mkdirSync`，会抛 `FileSystemException`。
- **已修**：`openAppConnection` 已 `if (!base.existsSync()) base.createSync(recursive: true);`。`readSqliteUserVersion` 走的是 `File(path).existsSync()`，没有写操作，没问题。
- **建议**：在 `app_bootstrap.dart` 启动时统一 `await AppPaths.ensureDirs();` 把 `<base>/备份/` 也建好。

### M-7：`AppDatabase.I` 静态可变单例在测试间相互污染

- **文件**：`src/lib/db/app_database.dart:79-89`。
- **根因**：与 M-5 重叠，单独提一下：`_instance` 是 mutable static，并发 `bootstrapApp` 会相互覆盖。
- **建议**：在 `bootstrapApp` 入口 `assert(_instance == null, 'bootstrapApp 只能调用一次')`，或在测试里 `setUp(() => AppDatabase.I = null)`。

---

## 四、优化建议（可选）

### O-1：`_dumpTable` / `_loadTable` 走 `customSelect` + 手写 SQL 拼装

- **位置**：`src/lib/security/data_export.dart:97-133`。
- **建议**：直接用 Drift 生成的 `db.contacts` Companion `insertMode: InsertMode.insertOrReplace`，更安全、避免类型不匹配（`DateTime` 序列化当前是 `Variable.withDateTime` 但导入端未做 ms / us 转换）。

### O-2：`BulterBoxes.versionIds` 用 Map 顺序与 `knownBoxNames` 不一致时会丢

- **位置**：`src/lib/storage/box_names.dart:16-22`。
- **建议**：改用 `static const List<(String, int)>` 元组或显式 `LinkedHashMap`。

### O-3：`VectorStore.deleteBySource` 当前会跨表删向量

- **位置**：`src/lib/db/vector_store.dart`。
- **建议**：先 `isVecAvailable()` 守门，并在删除前做事务包裹 `db.transaction(() => delete + log)`。

### O-4：DAO 里 `sumExpenseCents` 等聚合走 `customSelect`

- **位置**：`src/lib/modules/wealth/db/wealth_daos.dart`。
- **建议**：直接用 Drift `transactions.amountCents.sum()` + `where` 链式表达式生成。

### O-5：`bootstrapApp` 启动时同步注册 Tool/SubAgent 后续将变重

- **位置**：`src/lib/app_bootstrap.dart:39-50`。
- **建议**：把 `ToolRegistry` / `SubAgentRegistry` 同步方法改成 `Future<void> registerAsync()` 并 `await` 链，Step 5 后再统一重构。

---

## 五、测试覆盖

| 测试文件                              | 覆盖范围                          | 通过 |
|---------------------------------------|-----------------------------------|------|
| `test/widget_test.dart`               | Step 1 烟测：bootstrap + 7 模块   | ✅   |
| `test/hive_test.dart`                 | BulterBoxes / 初始化 / Box 打开   | ✅   |
| `test/module_registry_test.dart`      | bootstrapApp 7 模块 + table/DAO 类 | ✅  |
| `test/db_migration_test.dart`         | schemaVersion / 备份 / 回滚 / 清理 | ✅  |
| `test/dao_crud_test.dart`             | 6 模块 DAO + Stream + 聚合        | ✅   |
| `test/data_export_test.dart`          | 导出 / 导入 / 异常路径            | ✅   |
| `test/ai_*`（Step 5+）                | AI 工具 / 子 Agent                | —    |

**总计：26 个 test case 全部通过；sqlite-vec 在 Windows 测试环境的加载失败已降级，主库测试不受影响。**

---

## 六、Step 2 完成度自检

对照 `doc/first/plan.md` Step 2 完成标准 1–8：

1. ✅ Hive / Drift / sqlite-vec 三套存储全部接入
2. ✅ 22 张业务表全部建好（按模块拆分 `db/*_tables.dart`）
3. ✅ 7 个 DAO（含 Demo）通过 `BulterModule` 接口动态注册
4. ✅ `schemaVersion = 1` + 备份 / 回滚 / 清理三件套就绪
5. ✅ 数据导出 / 导入兜底功能可用
6. ✅ 26 个测试全通过
7. ✅ `flutter analyze` 0 error（warning 仅 `avoid_print` 一类）
8. ⚠️ 派生文件 `.g.dart` 入版本控制（建议在下个 PR 修复后再打 0.2.0 tag）

**结论：Step 2 主体已完成，遗留严重 / 一般问题建议在 Step 3 前集中修复。**
