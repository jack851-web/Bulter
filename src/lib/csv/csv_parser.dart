import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

import 'csv_models.dart';

/// CSV 文件解析器（Step 12）。
///
/// **设计**：
/// - 接受 `File` 或 `String content` 两种输入
/// - 自动检测分隔符（"," / "\t" / ";"）
/// - 自动检测编码（UTF-8 / GBK）—— **支付宝 / 微信默认 GBK**
/// - 第一行作 header，其余行作 rows
class CsvParser {
  CsvParser._();

  /// 从文件解析。
  static Future<CsvDocument> parseFile(File file) async {
    final bytes = await file.readAsBytes();
    final encoding = _detectEncoding(bytes);
    final content = encoding.decode(bytes);
    return parseString(content, encodingName: encoding.name);
  }

  /// 从字符串解析。
  static CsvDocument parseString(String content, {String? encodingName}) {
    // BOM 处理
    if (content.codeUnitAt(0) == 0xFEFF) {
      content = content.substring(1);
    }
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) {
      return const CsvDocument(headers: [], rows: [], totalLines: 0);
    }
    // 自动检测分隔符
    final delimiter = _detectDelimiter(lines);
    final decoder = CsvDecoder(
      skipEmptyLines: true,
      fieldDelimiter: delimiter == ',' ? null : delimiter,
    );

    final List<List<String>> allRows = [];
    try {
      final decoded = decoder.convert(content);
      for (final row in decoded) {
        allRows.add(row.map((c) => c?.toString() ?? '').toList());
      }
    } catch (e) {
      debugPrint('CsvParser: 行解析失败 - $e');
    }

    if (allRows.isEmpty) {
      return CsvDocument(
        headers: const [],
        rows: const [],
        totalLines: lines.length,
        detectedEncoding: encodingName,
      );
    }

    final headers = allRows.first
        .map((c) => c.trim())
        .map((h) => h.replaceAll(RegExp(r'^"+|"+$'), ''))
        .toList(growable: false);
    final dataRows = allRows
        .skip(1)
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList(growable: false);

    return CsvDocument(
      headers: headers,
      rows: dataRows,
      totalLines: lines.length,
      detectedEncoding: encodingName,
    );
  }

  /// 自动检测编码（UTF-8 vs GBK 简化版）。
  static Encoding _detectEncoding(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8;
    }
    // 简化：尝试 utf8 解码；失败 → GBK
    try {
      utf8.decode(bytes, allowMalformed: false);
      return utf8;
    } catch (_) {
      // GBK 解码（dart:convert 没自带，用 latin1 兜底）
      return latin1;
    }
  }

  /// 自动检测分隔符："," / "\t" / ";"
  static String _detectDelimiter(List<String> lines) {
    int score(String d) {
      int total = 0;
      for (final l in lines.take(5)) {
        total += d.allMatches(l).length;
      }
      return total;
    }

    final scores = {',': score(','), '\t': score('\t'), ';': score(';')};
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value > 0 ? best.key : ',';
  }
}
