import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vec/sqlite_vec.dart';

bool _vecExtensionRegistered = false;
bool _vecExtensionFailed = false;

/// 全局注册 sqlite-vec 扩展。多次调用幂等。
///
/// sqlite3_flutter_libs 自带的 sqlite3 不开放 `load_extension` SQL 函数，
/// 必须通过 `sqlite3_auto_extension` 机制注册。`sqlite_vec` 包的入口符号是
/// `sqlite3_vec_init`。
///
/// 在测试 / 不支持的环境下会失败但不会抛错，向量相关 API 后续会被跳过。
void _ensureVecExtensionRegistered() {
  if (_vecExtensionRegistered || _vecExtensionFailed) return;
  try {
    sqlite3.ensureExtensionLoaded(
      SqliteExtension.inLibrary(vec0, 'sqlite3_vec_init'),
    );
    _vecExtensionRegistered = true;
  } on Object catch (e) {
    _vecExtensionFailed = true;
    // ignore: avoid_print
    print('[Bulter] sqlite-vec 扩展加载失败，向量功能将不可用: $e');
  }
}

/// 向量扩展是否可用。
bool isVecAvailable() => _vecExtensionRegistered;

/// 打开 Bulter 主数据库连接。
///
/// - 通过 [sqlite3_flutter_libs] 加载动态库，并通过 [sqlite_vec] 注册 vec0 扩展。
/// - 测试场景下走 [openInMemoryConnection]。
/// - [subdir] 用于指定子目录（测试场景可传临时目录）。
/// - [overrideFilePath] 直接指定文件路径。
QueryExecutor openAppConnection({String? overrideFilePath, String? subdir}) {
  _ensureVecExtensionRegistered();
  return LazyDatabase(() async {
    if (overrideFilePath != null) {
      return NativeDatabase(File(overrideFilePath));
    }
    final base = subdir != null
        ? Directory(subdir)
        : await getApplicationDocumentsDirectory();
    if (!base.existsSync()) {
      base.createSync(recursive: true);
    }
    final file = File(p.join(base.path, 'bulter.sqlite'));
    return NativeDatabase(file);
  });
}

/// 测试场景下使用纯内存数据库（同样注册 sqlite-vec 扩展）。
QueryExecutor openInMemoryConnection() {
  _ensureVecExtensionRegistered();
  return NativeDatabase.memory();
}

/// 读取 SQLite 文件的 user_version（即 Drift 的 schemaVersion）。
///
/// 文件不存在或读取失败时返回 0（视为新库）。
/// 不通过 Drift，绕开 user_version 的写入与 onCreate 副作用。
Future<int> readSqliteUserVersion({
  String? overrideFilePath,
  String? subdir,
}) async {
  final path =
      overrideFilePath ??
      p.join(
        subdir != null
            ? subdir
            : (await getApplicationDocumentsDirectory()).path,
        'bulter.sqlite',
      );
  final file = File(path);
  if (!file.existsSync()) return 0;
  try {
    final db = sqlite3.open(path);
    try {
      final result = db.select('PRAGMA user_version');
      return result.first.columnAt(0) as int;
    } finally {
      db.dispose();
    }
  } catch (_) {
    return 0;
  }
}
