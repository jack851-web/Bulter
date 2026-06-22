import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../csv/csv_field_mapper.dart';
import '../../csv/csv_importer.dart';
import '../../csv/csv_models.dart';
import '../../csv/csv_parser.dart';
import '../../csv/csv_validator.dart';
import '../../theme/tokens.dart';

/// CSV 批量导入向导（Step 12）。
///
/// **4 步流程**：
/// 1. **选文件** —— file_picker 选 .csv
/// 2. **字段映射** —— 自动检测 → 用户调整 → 选模块
/// 3. **预览** —— 显示前 10 行 + 校验错误
/// 4. **执行** —— 调 [CsvImporter] → 显示 [CsvImportReport]
class CsvImportWizard extends StatefulWidget {
  final CsvModule initialModule;
  const CsvImportWizard({super.key, this.initialModule = CsvModule.wealth});

  @override
  State<CsvImportWizard> createState() => _CsvImportWizardState();
}

class _CsvImportWizardState extends State<CsvImportWizard> {
  int _step = 0;

  // 状态
  File? _file;
  CsvDocument? _doc;
  CsvModule _module = CsvModule.wealth;
  List<CsvFieldMapping> _mapping = const [];
  CsvPreset? _detectedPreset;
  CsvImportReport? _report;
  bool _importing = false;

  // 派生
  List<CsvRow> get _rows {
    if (_doc == null || _mapping.isEmpty) return const [];
    return [
      for (var i = 0; i < _doc!.rows.length; i++)
        CsvRow(
          sourceLine: i + 2,
          raw: {
            for (var j = 0; j < _doc!.headers.length; j++)
              _doc!.headers[j]: _doc!.rows[i].length > j ? _doc!.rows[i][j] : '',
          },
          mapping: {
            for (final m in _mapping) m.columnName: m.field,
          },
        ),
    ];
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      final doc = await CsvParser.parseFile(file);
      final mapping = CsvFieldMapper.autoDetect(doc.headers, module: _module);
      final preset = CsvFieldMapper.detectPreset(doc.headers, module: _module);
      setState(() {
        _file = file;
        _doc = doc;
        _mapping = mapping;
        _detectedPreset = preset;
        _step = 1;
      });
    } catch (e) {
      _snack('解析失败：$e', isError: true);
    }
  }

  void _onModuleChanged(CsvModule? newModule) {
    if (newModule == null) return;
    setState(() {
      _module = newModule;
      if (_doc != null) {
        _detectedPreset = CsvFieldMapper.detectPreset(_doc!.headers, module: _module);
        if (_detectedPreset != null) {
          _mapping = CsvFieldMapper.loadPresetMapping(_detectedPreset!, _doc!.headers);
        } else {
          _mapping = CsvFieldMapper.autoDetect(_doc!.headers, module: _module);
        }
      }
    });
  }

  void _onMappingChanged(String column, CsvField? field) {
    setState(() {
      _mapping = CsvFieldMapper.updateMapping(
        _mapping,
        columnName: column,
        newField: field,
      );
    });
  }

  Future<void> _runImport() async {
    if (_doc == null) return;
    final missing = CsvFieldMapper.missingRequired(_module, _mapping);
    if (missing.isNotEmpty) {
      _snack('必填字段未映射：${missing.map((f) => f.label).join(', ')}',
          isError: true);
      return;
    }
    setState(() {
      _importing = true;
      _report = null;
    });
    try {
      final report = await CsvImporter.importBatch(
        module: _module,
        rows: _rows,
        mapping: _mapping,
      );
      setState(() {
        _report = report;
        _step = 3;
      });
    } catch (e) {
      _snack('导入异常：$e', isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? BulterColors.error : BulterColors.textSecondary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV 批量导入'),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _step,
        controlsBuilder: (context, details) => _controls(details),
        steps: [
          Step(
            isActive: _step >= 0,
            title: const Text('选 CSV 文件'),
            content: _pickFileStep(),
          ),
          Step(
            isActive: _step >= 1,
            title: const Text('字段映射'),
            content: _mappingStep(),
          ),
          Step(
            isActive: _step >= 2,
            title: const Text('预览 / 校验'),
            content: _previewStep(),
          ),
          Step(
            isActive: _step >= 3,
            title: const Text('导入结果'),
            content: _reportStep(),
          ),
        ],
      ),
    );
  }

  Widget _controls(ControlsDetails details) {
    if (details.stepIndex == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file),
          label: const Text('选择 .csv 文件'),
        ),
      );
    }
    if (details.stepIndex == 1) {
      return Row(
        children: [
          TextButton(
            onPressed: details.onStepCancel,
            child: const Text('上一步'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() => _step = 2),
            child: const Text('下一步'),
          ),
        ],
      );
    }
    if (details.stepIndex == 2) {
      return Row(
        children: [
          TextButton(
            onPressed: details.onStepCancel,
            child: const Text('上一步'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _importing ? null : _runImport,
            child: _importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('开始导入'),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }

  Widget _pickFileStep() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择要导入的 CSV 文件：'),
          const SizedBox(height: 8),
          if (_file != null)
            Text('已选择：${_file!.path.split('/').last}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          const Text(
            '支持格式：财富账单（支付宝 / 微信）、成长学习、思想读后感、健康记录',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _mappingStep() {
    if (_doc == null) return const Text('请先选择文件');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('目标模块：'),
        const SizedBox(height: 4),
        DropdownButton<CsvModule>(
          value: _module,
          isExpanded: true,
          items: [
            for (final m in CsvModule.values)
              if (m != CsvModule.unknown)
                DropdownMenuItem(value: m, child: Text(m.label)),
          ],
          onChanged: _onModuleChanged,
        ),
        const SizedBox(height: 16),
        if (_detectedPreset != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BulterColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16),
                const SizedBox(width: 6),
                Text('已识别为 ${_detectedPreset!.name}，自动套用默认映射'),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text('列 → 字段映射：'),
        const SizedBox(height: 4),
        for (final m in _mapping)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(m.columnName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: DropdownButton<CsvField?>(
                    value: m.field,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('（跳过）', style: TextStyle(color: Colors.grey)),
                      ),
                      for (final f in CsvField.values)
                        if (f.isValidFor(_module))
                          DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (f) => _onMappingChanged(m.columnName, f),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _previewStep() {
    if (_doc == null) return const Text('请先选择文件');
    final previewRows = _rows.take(10).toList();
    final validations = CsvValidator.validateBatch(previewRows, _module);
    final errorCount = validations.where((v) => !v.isValid).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('共 ${_doc!.rowCount} 行（预览前 ${previewRows.length} 行）'),
        const SizedBox(height: 4),
        if (errorCount > 0)
          Text(
            '⚠️ 校验未通过：$errorCount 行（继续导入时这些行会被跳过）',
            style: const TextStyle(color: Colors.orange),
          )
        else
          const Text('✅ 校验全部通过', style: TextStyle(color: Colors.green)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: [
              for (final h in _doc!.headers) DataColumn(label: Text(h)),
            ],
            rows: [
              for (var i = 0; i < previewRows.length; i++)
                DataRow(cells: [
                  for (final h in _doc!.headers)
                    DataCell(Text(
                      previewRows[i].raw[h] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: validations[i].isValid
                            ? null
                            : BulterColors.error,
                      ),
                    )),
                ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reportStep() {
    if (_report == null) return const Text('尚未导入');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _report!.summary(),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}
