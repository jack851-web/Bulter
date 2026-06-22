/// CSV 导入数据模型（Step 12）。
///
/// 设计：
/// - **类型安全**：所有字段用 enum 标识，避免拼写错误
/// - **可序列化**：每条 ImportResult 可直接 `.toJson()` 存 Drift / 上传服务器
/// - **错误聚合**：ImportReport 同时记录成功 / 失败行 + 失败原因
library;

/// CSV 数据归属模块。
enum CsvModule {
  wealth('wealth', '财富账单'),
  growth('growth', '成长学习'),
  thought('thought', '思想读后感'),
  health('health', '健康记录'),
  unknown('unknown', '未知');

  final String id;
  final String label;
  const CsvModule(this.id, this.label);

  static CsvModule fromId(String id) =>
      CsvModule.values.firstWhere((m) => m.id == id,
          orElse: () => CsvModule.unknown);
}

/// CSV 列 → 模块字段 映射。
///
/// 一条 [CsvFieldMapping] 代表"CSV 第 X 列 → 模块某字段"。
enum CsvField {
  // —— 通用字段 ——
  note('备注'),
  date('日期'),
  amount('金额'),
  category('分类'),

  // —— 财富扩展 ——
  account('账户'),
  type('收/支'), // income / expense
  counterparty('交易对方'),

  // —— 成长扩展 ——
  title('标题'),
  durationMinutes('时长(分钟)'),
  resourceType('类型'), // book / course / article
  rating('评分'),

  // —— 思想扩展 ——
  author('作者'),
  bookTitle('书名'),
  content('内容'),

  // —— 健康扩展 ——
  metricName('指标名'),
  metricValue('指标值'),
  metricUnit('单位');

  final String label;
  const CsvField(this.label);

  /// 是否属于指定模块的合法字段。
  bool isValidFor(CsvModule module) {
    switch (module) {
      case CsvModule.wealth:
        return const {
          CsvField.note,
          CsvField.date,
          CsvField.amount,
          CsvField.category,
          CsvField.account,
          CsvField.type,
          CsvField.counterparty,
        }.contains(this);
      case CsvModule.growth:
        return const {
          CsvField.title,
          CsvField.date,
          CsvField.note,
          CsvField.durationMinutes,
          CsvField.resourceType,
          CsvField.rating,
          CsvField.category,
        }.contains(this);
      case CsvModule.thought:
        return const {
          CsvField.title,
          CsvField.author,
          CsvField.date,
          CsvField.content,
          CsvField.rating,
        }.contains(this);
      case CsvModule.health:
        return const {
          CsvField.date,
          CsvField.metricName,
          CsvField.metricValue,
          CsvField.metricUnit,
          CsvField.note,
        }.contains(this);
      case CsvModule.unknown:
        return false;
    }
  }
}

/// 一行 CSV 数据 + 用户确定的字段映射。
class CsvRow {
  /// 原始数据（key = CSV 列名，value = 该单元格字符串）。
  final Map<String, String> raw;

  /// 该行在原 CSV 中的行号（1-based，第一行为 header）。
  final int sourceLine;

  /// 用户为该 CSV 列指定的模块字段（`null` = 跳过）。
  final Map<String, CsvField?> mapping;

  const CsvRow({
    required this.raw,
    required this.sourceLine,
    required this.mapping,
  });

  /// 取映射后的字段值（trim 后）。
  String? get(CsvField field) {
    for (final entry in mapping.entries) {
      if (entry.value == field) {
        final v = raw[entry.key]?.trim();
        if (v == null || v.isEmpty) return null;
        return v;
      }
    }
    return null;
  }

  /// 取映射后的字段值（必填，缺失返回空字符串）。
  String must(CsvField field) => get(field) ?? '';
}

/// 字段映射规则。
class CsvFieldMapping {
  /// CSV 列名（key）。
  final String columnName;

  /// 映射到模块字段（null = 跳过此列）。
  final CsvField? field;

  const CsvFieldMapping({required this.columnName, this.field});

  CsvFieldMapping copyWith({String? columnName, CsvField? field}) =>
      CsvFieldMapping(
        columnName: columnName ?? this.columnName,
        field: field ?? this.field,
      );
}

/// 整张 CSV 的解析结果。
class CsvDocument {
  final List<String> headers;
  final List<List<String>> rows;
  final int totalLines;
  final String? detectedEncoding;

  const CsvDocument({
    required this.headers,
    required this.rows,
    required this.totalLines,
    this.detectedEncoding,
  });

  bool get isEmpty => headers.isEmpty && rows.isEmpty;
  int get columnCount => headers.length;
  int get rowCount => rows.length;
}

/// 单行校验错误。
class CsvRowError {
  final int lineNumber;
  final String message;
  const CsvRowError(this.lineNumber, this.message);

  @override
  String toString() => '第 $lineNumber 行: $message';
}

/// 单行校验结果。
class CsvRowValidation {
  final CsvRow row;
  final List<CsvRowError> errors;

  const CsvRowValidation({required this.row, required this.errors});

  bool get isValid => errors.isEmpty;
}

/// 整批导入结果。
class CsvImportReport {
  final CsvModule module;
  final int totalRows;
  final int successCount;
  final int skippedCount;
  final List<CsvRowError> errors;
  final Duration elapsed;

  const CsvImportReport({
    required this.module,
    required this.totalRows,
    required this.successCount,
    required this.skippedCount,
    required this.errors,
    required this.elapsed,
  });

  int get failureCount => errors.length;
  bool get hasErrors => errors.isNotEmpty;
  String summary() {
    final buf = StringBuffer();
    buf.writeln('导入完成（${elapsed.inMilliseconds} ms）');
    buf.writeln('  模块：${module.label}');
    buf.writeln('  总行数：$totalRows');
    buf.writeln('  成功：$successCount');
    if (skippedCount > 0) buf.writeln('  跳过（重复）：$skippedCount');
    if (hasErrors) {
      buf.writeln('  失败：${failureCount}');
      buf.writeln('  失败原因（前 10 条）：');
      for (final e in errors.take(10)) {
        buf.writeln('    - $e');
      }
    }
    return buf.toString().trim();
  }
}

/// 预设格式（开箱即用：支付宝 / 微信账单）。
abstract class CsvPreset {
  String get name;
  CsvModule get module;
  String get signatureHeader; // 用于自动识别的特征 header（如 "交易号" / "商户订单号"）
  List<CsvFieldMapping> get defaultMapping;
}
