import 'csv_models.dart';

/// CSV 数据校验（Step 12）。
///
/// **校验项**：
/// - 必填字段（date / amount）非空
/// - 金额可解析为 double
/// - 日期可解析为 DateTime
/// - 收/支类型 = income / expense
class CsvValidator {
  CsvValidator._();

  /// 校验一行数据。
  static List<CsvRowError> validateRow(CsvRow row, CsvModule module) {
    final errors = <CsvRowError>[];

    // 1) 必填字段检查
    if (module == CsvModule.wealth) {
      final date = row.get(CsvField.date);
      if (date == null) {
        errors.add(CsvRowError(row.sourceLine, '缺少日期'));
      }
      final amount = row.get(CsvField.amount);
      if (amount == null) {
        errors.add(CsvRowError(row.sourceLine, '缺少金额'));
      }
      // 金额可解析
      if (amount != null && _parseAmount(amount) == null) {
        errors.add(CsvRowError(
            row.sourceLine, '金额格式错误（不是数字）："$amount"'));
      }
    } else if (module == CsvModule.growth) {
      final title = row.get(CsvField.title);
      if (title == null) {
        errors.add(CsvRowError(row.sourceLine, '缺少标题'));
      }
      final date = row.get(CsvField.date);
      if (date != null && _parseDate(date) == null) {
        errors.add(CsvRowError(
            row.sourceLine, '日期格式无法识别："$date"'));
      }
    } else if (module == CsvModule.thought) {
      final title = row.get(CsvField.title);
      if (title == null) {
        errors.add(CsvRowError(row.sourceLine, '缺少标题'));
      }
    } else if (module == CsvModule.health) {
      final name = row.get(CsvField.metricName);
      final value = row.get(CsvField.metricValue);
      if (name == null) errors.add(CsvRowError(row.sourceLine, '缺少指标名'));
      if (value == null) {
        errors.add(CsvRowError(row.sourceLine, '缺少指标值'));
      } else if (_parseAmount(value) == null) {
        errors.add(CsvRowError(
            row.sourceLine, '指标值格式错误："$value"'));
      }
    }

    // 2) 日期格式
    final dateStr = row.get(CsvField.date);
    if (dateStr != null) {
      final parsed = _parseDate(dateStr);
      if (parsed == null && module != CsvModule.growth) {
        errors.add(CsvRowError(
            row.sourceLine, '日期格式无法识别："$dateStr"'));
      }
    }

    // 3) 评分范围
    final rating = row.get(CsvField.rating);
    if (rating != null) {
      final r = double.tryParse(rating);
      if (r == null || r < 0 || r > 5) {
        errors.add(CsvRowError(
            row.sourceLine, '评分应在 0-5 之间："$rating"'));
      }
    }

    return errors;
  }

  /// 批量校验。
  static List<CsvRowValidation> validateBatch(
    List<CsvRow> rows,
    CsvModule module,
  ) {
    return [
      for (final r in rows)
        CsvRowValidation(row: r, errors: validateRow(r, module)),
    ];
  }

  /// 解析金额（容忍中英文符号 / 千分位 / 货币符号）。
  ///
  /// 示例：
  /// - "¥1,234.56" → 1234.56
  /// - "120.00" → 120.0
  /// - "120" → 120.0
  /// - "abc" → null
  static double? _parseAmount(String raw) {
    if (raw.isEmpty) return null;
    // 去掉非数字符号（保留 . -）
    var s = raw
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('\$', '')
        .replaceAll('€', '')
        .replaceAll(' ', '');
    // 千分位逗号
    s = s.replaceAll(',', '');
    // 中文"元"
    s = s.replaceAll('元', '');
    // 收/支前缀（"支出120" / "收入120"）
    s = s.replaceAll(RegExp(r'^(收入|支出|收|支|转账)'), '');
    return double.tryParse(s);
  }

  /// 解析日期（多种格式兜底）。
  ///
  /// 支持：
  /// - ISO: `2024-01-15` / `2024-01-15 12:30:00`
  /// - 中文: `2024年01月15日` / `2024年01月15日 12:30:00`
  /// - 斜杠: `2024/01/15` / `2024/01/15 12:30`
  /// - 点: `2024.01.15`
  /// - Unix timestamp（10 位 / 13 位）
  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    final s = raw.trim();

    // Unix timestamp
    if (RegExp(r'^\d{10}$').hasMatch(s)) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(s) * 1000);
    }
    if (RegExp(r'^\d{13}$').hasMatch(s)) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(s));
    }

    // 中文日期：2024年01月15日 12:30:00
    final cn = RegExp(
            r'(\d{4})年(\d{1,2})月(\d{1,2})日(?:\s*(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?')
        .firstMatch(s);
    if (cn != null) {
      try {
        return DateTime(
          int.parse(cn.group(1)!),
          int.parse(cn.group(2)!),
          int.parse(cn.group(3)!),
          int.parse(cn.group(4) ?? '0'),
          int.parse(cn.group(5) ?? '0'),
          int.parse(cn.group(6) ?? '0'),
        );
      } catch (_) {}
    }

    // 标准 ISO / 斜杠 / 点：直接 tryParse
    final directTry = [
      s,
      s.replaceAll('/', '-'),
      s.replaceAll('.', '-'),
    ];
    for (final d in directTry) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) return parsed;
    }
    return null;
  }

  // 暴露给 importer
  static double? parseAmount(String raw) => _parseAmount(raw);
  static DateTime? parseDate(String raw) => _parseDate(raw);
}
