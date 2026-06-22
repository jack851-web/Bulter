// Bulter 第 12 步：CSV 批量导入
//
// 验证：
// 1) CSV 字符串解析（header / rows / 分隔符检测）
// 2) 字段自动识别（按列名关键字）
// 3) 预设格式检测（支付宝 / 微信）
// 4) 数据校验（金额 / 日期 / 评分）
// 5) 字段映射完整性（必填字段检查）

import 'package:bulter/csv/csv_field_mapper.dart';
import 'package:bulter/csv/csv_models.dart';
import 'package:bulter/csv/csv_parser.dart';
import 'package:bulter/csv/csv_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvParser', () {
    test('标准 CSV（逗号分隔）', () {
      const csv = '''日期,金额,备注
2024-01-15,120.50,午餐
2024-01-16,50.00,地铁''';
      final doc = CsvParser.parseString(csv);
      expect(doc.headers, ['日期', '金额', '备注']);
      expect(doc.rowCount, 2);
      expect(doc.rows[0], ['2024-01-15', '120.50', '午餐']);
      expect(doc.rows[1], ['2024-01-16', '50.00', '地铁']);
    });

    test('UTF-8 BOM 自动去除', () {
      const csv = '\uFEFF日期,金额\n2024-01-15,100';
      final doc = CsvParser.parseString(csv);
      expect(doc.headers.first, '日期'); // 没有 \uFEFF
    });

    test('制表符分隔', () {
      const csv = '日期\t金额\t备注\n2024-01-15\t100\t午餐';
      final doc = CsvParser.parseString(csv);
      expect(doc.columnCount, 3);
      expect(doc.rowCount, 1);
    });

    test('空行跳过', () {
      const csv = '''日期,金额
2024-01-15,100

2024-01-16,200''';
      final doc = CsvParser.parseString(csv);
      expect(doc.rowCount, 2); // 空行已跳过
    });
  });

  group('CsvFieldMapper 自动识别', () {
    test('财富账单字段识别', () {
      const headers = ['交易时间', '交易对方', '金额(元)', '收/支', '备注'];
      final mapping = CsvFieldMapper.autoDetect(
        headers,
        module: CsvModule.wealth,
      );
      final mapped = {
        for (final m in mapping)
          if (m.field != null) m.columnName: m.field!,
      };
      expect(mapped['交易时间'], CsvField.date);
      expect(mapped['交易对方'], CsvField.counterparty);
      expect(mapped['金额(元)'], CsvField.amount);
      expect(mapped['收/支'], CsvField.type);
      expect(mapped['备注'], CsvField.note);
    });

    test('成长字段识别', () {
      const headers = ['标题', '日期', '时长', '类型', '评分'];
      final mapping = CsvFieldMapper.autoDetect(
        headers,
        module: CsvModule.growth,
      );
      final mapped = {
        for (final m in mapping)
          if (m.field != null) m.columnName: m.field!,
      };
      expect(mapped['标题'], CsvField.title);
      expect(mapped['日期'], CsvField.date);
      expect(mapped['时长'], CsvField.durationMinutes);
      expect(mapped['评分'], CsvField.rating);
    });
  });

  group('CsvFieldMapper 预设检测', () {
    test('支付宝账单检测', () {
      const headers = ['交易号', '交易创建时间', '交易对方', '金额（元）'];
      final preset = CsvFieldMapper.detectPreset(
        headers,
        module: CsvModule.wealth,
      );
      expect(preset, isNotNull);
      expect(preset!.name, '支付宝账单');
    });

    test('微信账单检测', () {
      const headers = ['交易单号', '交易时间', '交易类型', '金额(元)'];
      final preset = CsvFieldMapper.detectPreset(
        headers,
        module: CsvModule.wealth,
      );
      expect(preset, isNotNull);
      expect(preset!.name, '微信账单');
    });

    test('未知格式返回 null', () {
      const headers = ['foo', 'bar', 'baz'];
      final preset = CsvFieldMapper.detectPreset(
        headers,
        module: CsvModule.wealth,
      );
      expect(preset, null);
    });
  });

  group('CsvValidator', () {
    test('金额解析：中文符号 / 千分位 / 元 后缀', () {
      expect(CsvValidator.parseAmount('120'), 120.0);
      expect(CsvValidator.parseAmount('¥120.50'), 120.5);
      expect(CsvValidator.parseAmount('1,234.56'), 1234.56);
      expect(CsvValidator.parseAmount('120元'), 120.0);
      expect(CsvValidator.parseAmount('支出120'), 120.0);
      expect(CsvValidator.parseAmount('abc'), null);
    });

    test('日期解析：多种格式', () {
      expect(CsvValidator.parseDate('2024-01-15'), DateTime(2024, 1, 15));
      expect(CsvValidator.parseDate('2024/01/15'), DateTime(2024, 1, 15));
      expect(CsvValidator.parseDate('2024年01月15日'), DateTime(2024, 1, 15));
      expect(CsvValidator.parseDate('1705276800'), isNotNull); // Unix ts
      expect(CsvValidator.parseDate('2024-01-15 12:30:00'), isNotNull);
      expect(CsvValidator.parseDate('not a date'), null);
    });

    test('财富行校验：缺日期报错', () {
      final row = CsvRow(
        sourceLine: 2,
        raw: {'金额': '120'},
        mapping: {'金额': CsvField.amount},
      );
      final errors = CsvValidator.validateRow(row, CsvModule.wealth);
      expect(errors.length, 1);
      expect(errors.first.message, contains('缺少日期'));
    });

    test('财富行校验：金额非数字', () {
      final row = CsvRow(
        sourceLine: 2,
        raw: {'日期': '2024-01-15', '金额': 'abc'},
        mapping: {'日期': CsvField.date, '金额': CsvField.amount},
      );
      final errors = CsvValidator.validateRow(row, CsvModule.wealth);
      expect(errors.any((e) => e.message.contains('金额')), true);
    });

    test('评分范围校验', () {
      final row = CsvRow(
        sourceLine: 2,
        raw: {'评分': '10'},
        mapping: {'评分': CsvField.rating},
      );
      final errors = CsvValidator.validateRow(row, CsvModule.growth);
      expect(errors.any((e) => e.message.contains('评分')), true);
    });

    test('健康指标值非数字', () {
      final row = CsvRow(
        sourceLine: 2,
        raw: {'指标名': '体重', '指标值': 'abc'},
        mapping: {'指标名': CsvField.metricName, '指标值': CsvField.metricValue},
      );
      final errors = CsvValidator.validateRow(row, CsvModule.health);
      expect(errors.any((e) => e.message.contains('指标值')), true);
    });
  });

  group('CsvFieldMapper 必填字段检查', () {
    test('财富缺 amount 必填', () {
      const mapping = [
        CsvFieldMapping(columnName: '日期', field: CsvField.date),
        CsvFieldMapping(columnName: '备注', field: CsvField.note),
      ];
      final missing = CsvFieldMapper.missingRequired(CsvModule.wealth, mapping);
      expect(missing, contains(CsvField.amount));
    });

    test('财富完整映射无必填缺失', () {
      const mapping = [
        CsvFieldMapping(columnName: '日期', field: CsvField.date),
        CsvFieldMapping(columnName: '金额', field: CsvField.amount),
      ];
      final missing = CsvFieldMapper.missingRequired(CsvModule.wealth, mapping);
      expect(missing, isEmpty);
    });

    test('成长缺 title 必填', () {
      const mapping = [CsvFieldMapping(columnName: '日期', field: CsvField.date)];
      final missing = CsvFieldMapper.missingRequired(CsvModule.growth, mapping);
      expect(missing, contains(CsvField.title));
    });
  });
}
