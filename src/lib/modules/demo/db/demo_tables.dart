import 'package:drift/drift.dart';

/// Demo 模块 — 验证模块化：表 + DAO 都在本模块目录下，主 AppDatabase 静态
/// 引用本表即可。"新增模块 = 新建目录 + 在 registerAll 加一行"的最小动作。
///
/// 实际使用方是"模块化测试"：`DemoModule` 注册 → AppDatabase 自带 demo_items。

@DataClassName('DemoItem')
class DemoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
