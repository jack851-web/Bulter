import 'package:flutter/foundation.dart';

import 'csv_models.dart';
import 'presets.dart';

/// 字段自动识别 + 手动映射管理（Step 12）。
///
/// **自动识别规则**（按列名模糊匹配）：
/// - `date` / `时间` / `日期` / `Date` → CsvField.date
/// - `amount` / `金额` / `money` → CsvField.amount
/// - `note` / `备注` / `desc` / `说明` → CsvField.note
/// - ... 见 [_keywordMap]
///
/// **预设格式**：
/// - 支付宝账单 / 微信账单 → 直接识别 + 套用默认 mapping
class CsvFieldMapper {
  CsvFieldMapper._();

  /// 列名 → 模块字段 关键字映射（**首匹配**）。
  static final List<MapEntry<RegExp, CsvField>> _keywordMap = [
    // 日期
    MapEntry(
        RegExp(r'(日期|time|date|时间|datetime)', caseSensitive: false),
        CsvField.date),
    // 金额
    MapEntry(RegExp(r'(金额|amount|money|价|款)', caseSensitive: false),
        CsvField.amount),
    // 收/支
    MapEntry(
        RegExp(r'(收.?支|type|收支类型|direction)', caseSensitive: false),
        CsvField.type),
    // 分类
    MapEntry(RegExp(r'(分类|category|class)', caseSensitive: false),
        CsvField.category),
    // 备注
    MapEntry(
        RegExp(r'(备注|note|desc|说明|描述|remark)', caseSensitive: false),
        CsvField.note),
    // 账户
    MapEntry(RegExp(r'(账户|account|账号)', caseSensitive: false),
        CsvField.account),
    // 交易对方
    MapEntry(
        RegExp(r'(对方|counterparty|payee|from|to)', caseSensitive: false),
        CsvField.counterparty),
    // 标题
    MapEntry(RegExp(r'(标题|title|subject|name)', caseSensitive: false),
        CsvField.title),
    // 时长
    MapEntry(RegExp(r'(时长|duration|minutes)', caseSensitive: false),
        CsvField.durationMinutes),
    // 类型（资源类型）
    MapEntry(
        RegExp(r'(资源.?类型|resource.?type|format)', caseSensitive: false),
        CsvField.resourceType),
    // 评分
    MapEntry(RegExp(r'(评分|rating|score|stars)', caseSensitive: false),
        CsvField.rating),
    // 作者
    MapEntry(RegExp(r'(作者|author|writer)', caseSensitive: false),
        CsvField.author),
    // 书名（与 title 区分）
    MapEntry(RegExp(r'(书名|book)', caseSensitive: false), CsvField.bookTitle),
    // 内容
    MapEntry(RegExp(r'(内容|content|body|text)', caseSensitive: false),
        CsvField.content),
    // 健康指标
    MapEntry(
        RegExp(r'(指标.?名|metric.?name|item)', caseSensitive: false),
        CsvField.metricName),
    MapEntry(
        RegExp(r'(指标.?值|metric.?value|value)', caseSensitive: false),
        CsvField.metricValue),
    MapEntry(RegExp(r'(单位|unit)', caseSensitive: false), CsvField.metricUnit),
  ];

  /// 自动猜测列 → 字段映射。
  static List<CsvFieldMapping> autoDetect(
    List<String> headers, {
    required CsvModule module,
  }) {
    final mapping = <CsvFieldMapping>[];
    final usedFields = <CsvField>{};
    for (final h in headers) {
      final field = _matchKeyword(h, usedFields, module);
      mapping.add(CsvFieldMapping(columnName: h, field: field));
      if (field != null) usedFields.add(field);
    }
    return mapping;
  }

  /// 尝试匹配预设（支付宝 / 微信）。
  /// 命中 → 返回预设默认 mapping；否则 null。
  static CsvPreset? detectPreset(
    List<String> headers, {
    required CsvModule module,
  }) {
    for (final preset in CsvPresets.all) {
      if (preset.module != module) continue;
      if (preset.signatureHeader.isEmpty) continue;
      if (headers.contains(preset.signatureHeader)) {
        return preset;
      }
      // 宽松匹配：任一 signature header 在 headers 中
    }
    return null;
  }

  /// 加载预设的默认 mapping（按列名匹配 preset 里的 mapping）。
  static List<CsvFieldMapping> loadPresetMapping(
    CsvPreset preset,
    List<String> headers,
  ) {
    final out = <CsvFieldMapping>[];
    final usedFields = <CsvField>{};
    for (final h in headers) {
      final m = preset.defaultMapping.firstWhere(
        (m) => m.columnName == h,
        orElse: () => CsvFieldMapping(columnName: h),
      );
      final f = m.field != null && !usedFields.contains(m.field) ? m.field : null;
      out.add(CsvFieldMapping(columnName: h, field: f));
      if (f != null) usedFields.add(f);
    }
    return out;
  }

  static CsvField? _matchKeyword(
    String header,
    Set<CsvField> alreadyUsed,
    CsvModule module,
  ) {
    for (final entry in _keywordMap) {
      if (entry.key.hasMatch(header)) {
        final f = entry.value;
        if (!f.isValidFor(module)) continue;
        if (alreadyUsed.contains(f)) continue;
        return f;
      }
    }
    return null;
  }

  /// 用户手动调整某列映射。
  static List<CsvFieldMapping> updateMapping(
    List<CsvFieldMapping> current, {
    required String columnName,
    required CsvField? newField,
  }) {
    return [
      for (final m in current)
        if (m.columnName == columnName)
          m.copyWith(field: newField)
        else
          m,
    ];
  }

  /// 检查映射完整性：必填字段（`date` / `amount`）是否都已映射。
  static List<CsvField> missingRequired(CsvModule module, List<CsvFieldMapping> mapping) {
    final required = <CsvField>{};
    if (module == CsvModule.wealth) {
      required.add(CsvField.date);
      required.add(CsvField.amount);
    } else if (module == CsvModule.growth) {
      required.add(CsvField.date);
      required.add(CsvField.title);
    } else if (module == CsvModule.thought) {
      required.add(CsvField.title);
    } else if (module == CsvModule.health) {
      required.add(CsvField.date);
      required.add(CsvField.metricName);
      required.add(CsvField.metricValue);
    }
    final mapped = mapping.where((m) => m.field != null).map((m) => m.field!).toSet();
    return required.where((r) => !mapped.contains(r)).toList();
  }
}
