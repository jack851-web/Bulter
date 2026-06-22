import 'package:drift/drift.dart';

/// 截图历史表（Step 9 + Step 10）。
///
/// 每次截图保存一条记录：
/// - 缩略图本地路径（`thumbPath`）
/// - AI 推理结果（`inferredCategory` / `inferredConfidence` / `inferredSummary` / `inferredJson`）
/// - 用户最终归类（`userCategory` / `userActionsJson`）—— 与 AI 不同可手动改
/// - **Step 10**：`autoSinkStatus`（success / no_tools_called / no_api_key / dio_xxx / ...）
///
/// **隐私**：原图**永不保存**（截完即删），仅留缩略图。
@DataClassName('Screenshot')
class Screenshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get thumbPath => text()();
  TextColumn get packageName => text().nullable()();
  TextColumn get windowTitle => text().nullable()();
  TextColumn get textPreview => text().nullable()();
  TextColumn get inferredCategory => text().nullable()();
  RealColumn get inferredConfidence => real().nullable()();
  TextColumn get inferredSummary => text().nullable()();
  TextColumn get inferredJson => text().nullable()();

  /// 用户最终归类（relationship / growth / wealth / thought / health / other / chat / bill / article / report）
  TextColumn get userCategory => text().nullable()();

  /// 用户执行的动作列表 JSON（`[{"type":"add_contact","name":"..."}, ...]`）
  TextColumn get userActionsJson => text().nullable()();

  /// 确认时间（epoch ms）。null = 还没确认（pending 状态）。
  IntColumn get reviewedAt => integer().nullable()();

  /// 创建时间（epoch ms）。Drift 不自动管理时间戳（与全库一致）。
  IntColumn get createdAt => integer()();

  /// Step 10：自动入库状态（success / no_tools_called / no_api_key / dio_xxx / ...）。
  TextColumn get autoSinkStatus => text().nullable()();

  @override
  String get tableName => 'screenshots';
}
