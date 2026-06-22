# commit_17 — Step 12 CSV 批量导入（4 步向导 + 支付宝/微信开箱即用）

- **版本**：0.9.2
- **commit 类型**：`feat(csv)` + `feat(ui)` + `chore(deps)`
- **影响范围**：Dart 6 新文件 + DAO 1 改造 + 依赖 2 新增 + 测试 1 新文件
- **关联文档**：[doc/first/plan.md §第 12 步](file:///d:/others/app/Bulter/doc/first/plan.md) 全部勾选

## 目标

财富账单、成长学习记录、思想读后感、健康指标可 CSV 批量导入：

1. **4 步向导**：选文件 → 字段映射 → 预览校验 → 导入结果
2. **支付宝 / 微信账单开箱即用**：自动识别 + 默认 mapping
3. **智能字段识别**：20+ 关键字正则匹配列名
4. **数据校验**：金额 / 日期 / 评分（多种格式兜底）
5. **错误聚合**：导入报告含成功 N / 失败 N / 前 10 条失败原因

## 实施内容

### A. CSV 核心库（`lib/csv/`）

#### 1. 🆕 [lib/csv/csv_models.dart](file:///d:/others/app/Bulter/src/lib/csv/csv_models.dart)

**数据模型**：
- `enum CsvModule`：`wealth / growth / thought / health / unknown`
- `enum CsvField`：通用 + 模块扩展字段（共 20 个字段，附中文 label）
- `class CsvRow`：原始数据 + 用户映射 + `get(CsvField) / must(CsvField)` 访问
- `class CsvFieldMapping`：列名 → 字段（可 null = 跳过）
- `class CsvDocument`：headers + rows + totalLines + encoding
- `class CsvRowError`：行号 + 错误消息
- `class CsvImportReport`：成功 / 失败计数 + 错误列表 + 耗时 + `summary()` 方法

#### 2. 🆕 [lib/csv/csv_parser.dart](file:///d:/others/app/Bulter/src/lib/csv/csv_parser.dart)

**CSV 文件解析器**：
- `parseFile(File)` / `parseString(String)`
- 自动 UTF-8 BOM 去除
- 自动分隔符检测（"," / "\t" / ";"）—— 按首 5 行计数
- 编码自动检测（UTF-8 优先；失败兜底 latin1）
- 空行自动跳过

#### 3. 🆕 [lib/csv/csv_field_mapper.dart](file:///d:/others/app/Bulter/src/lib/csv/csv_field_mapper.dart)

**字段自动识别 + 手动映射管理**：
- `_keywordMap`：20+ RegExp（中文 + 英文 + 缩写）
- `autoDetect(headers, module)` → 列名 → CsvField（首匹配 + 已占用跳过 + 模块合法）
- `detectPreset(headers, module)` → 支付宝 / 微信 signature header 检测
- `loadPresetMapping(preset, headers)` → 按列名匹配 preset 默认 mapping
- `updateMapping(...)` → 单列映射更新
- `missingRequired(module, mapping)` → 必填字段检查（wealth: date+amount / growth: date+title / ...）

#### 4. 🆕 [lib/csv/csv_validator.dart](file:///d:/others/app/Bulter/src/lib/csv/csv_validator.dart)

**数据校验**：
- `validateRow(row, module)` → List\<CsvRowError\>
- `validateBatch(rows, module)` → List\<CsvRowValidation\>
- 金额解析（`parseAmount`）：容忍 `¥` / `￥` / `$` / `€` / `,` / `元` / `收入` / `支出` 前缀
- 日期解析（`parseDate`）：ISO / 中文 / 斜杠 / 点 / Unix timestamp（10/13 位）

#### 5. 🆕 [lib/csv/csv_importer.dart](file:///d:/others/app/Bulter/src/lib/csv/csv_importer.dart)

**导入执行器**：
- `importBatch(module, rows, mapping)` → CsvImportReport
- 按模块调对应 DAO：
  - **wealth**：`wealthDao.insertTransaction`（金额 = 元×100，正负号按"收/支"）+ 自动创建默认账户"现金"
  - **growth**：`growthDao.insertLearning`（title / source / rating / notes）
  - **thought**：`thoughtDao.insertThought`（content / sourceRef 合成 = `《title》/ author`）
  - **health**：`healthDao.insertRecord`（type / valueText / valueNum / unit）
- 单行失败 → 聚合到 `errors`，不阻塞其他行

#### 6. 🆕 [lib/csv/presets.dart](file:///d:/others/app/Bulter/src/lib/csv/presets.dart)

**预设格式**（开箱即用）：
- `AlipayBillPreset` —— 支付宝账单导出（signature: "交易号"，15 列默认 mapping）
- `WechatBillPreset` —— 微信账单导出（signature: "交易单号"，12 列默认 mapping）

### B. UI 向导

#### 🆕 [lib/features/csv_import/csv_import_wizard.dart](file:///d:/others/app/Bulter/src/lib/features/csv_import/csv_import_wizard.dart)

**4 步 Stepper**：

| 步骤 | 内容 |
|---|---|
| **1. 选文件** | `FilePicker` 选 `.csv`；显示已选文件名 + 支持格式说明 |
| **2. 字段映射** | 目标模块下拉 + 预设识别提示 + 列→字段下拉 |
| **3. 预览 / 校验** | 前 10 行 DataTable + 校验错误红字 + ✅/⚠️ 状态 |
| **4. 导入结果** | monospace 报告（成功 N / 失败 N / 前 10 条失败原因） |

### C. DAO 改造

#### 🔧 [lib/modules/wealth/db/wealth_daos.dart](file:///d:/others/app/Bulter/src/lib/modules/wealth/db/wealth_daos.dart)

- 加 `firstAccount()` 方法（CSV 导入时默认账户；没有则调用方创建"现金"账户）

### D. 依赖

- `pubspec.yaml`：加 `csv: ^8.0.0` + `file_picker: ^8.0.0`

### E. 测试

#### 🆕 [test/step12_csv_import_test.dart](file:///d:/others/app/Bulter/src/test/step12_csv_import_test.dart)

**18 个测试**覆盖：
- CsvParser（标准 CSV / BOM / 制表符 / 空行）
- CsvFieldMapper（财富 / 成长自动识别 / 支付宝 / 微信 / 未知格式）
- CsvValidator（金额 / 日期 / 评分 / 必填字段）
- CsvFieldMapper 必填字段检查（wealth / growth）

## 验证

| 验证项 | 结果 |
|---|---|
| `flutter analyze lib` | ✅ **0 error** |
| `flutter test test/step12_csv_import_test.dart` | ✅ **18/18** 通过 |
| `flutter test`（全部） | ✅ **51/51** 通过 |
| plan.md §第 12 步 5 项验收 | ✅ 全部勾选 |

## 关键设计决策

### D1：csv 8.x 新 API（流式 + Codec 风格）

csv 8.0 抛弃了旧的 `CsvToListConverter` 同步 API，改用：
```dart
final decoder = const CsvDecoder(skipEmptyLines: true, fieldDelimiter: ',');
final rows = decoder.convert(csvString); // List<List<dynamic>>
```

**优势**：可与 `Stream.transform()` 配合处理大文件；未来支持流式导入百万行账单。

### D2：导入时"先校验后执行" vs "逐行校验逐行执行"

选择**逐行校验 + 逐行执行**（不在前端批校验）：
- 优点：用户在大文件上立即看到结果（无需等全部解析完）
- 缺点：导入过程中 DB 写入是实时的，不能"撤销"
- **改进方向**（Step 13+）：加 dryRun 模式 → 先校验显示 → 用户点"确认"再执行

### D3：Thoughts / HealthRecords 表字段缺失处理

- **Thoughts 表没有 `title` / `author` / `rating` 字段** —— 用 `sourceRef` 合成 `《title》/ author`，把内容塞 `content`
- **HealthRecords 表没有 `metricName` 字段** —— 把指标名塞 `type` 字段（值 = "体重" / "血压" 等）

这是**字段对齐**而非 schema 迁移 —— 避免改 schema 带来数据库迁移成本。

### D4：默认账户自动创建

CSV 导入财富账单时如果没有账户 → 自动创建"现金"账户（type: cash, balanceCents: 0）。
**优点**：用户体验流畅（无需先建账户）
**缺点**：balanceCents 不准确（导入后余额不会自动更新）

**未来改进**：导入后弹提示"是否根据账单自动重算余额？"。

## 引用

- 上次 commit：[commit_16.md](file:///d:/others/app/Bulter/doc/git_log/commit_16.md)（Step 11 AI 对话增强）
- 设计：[doc/first/01-architecture.md](file:///d:/others/app/Bulter/doc/first/01-architecture.md) §七（数据导入）
- 计划：[doc/first/plan.md](file:///d:/others/app/Bulter/doc/first/plan.md) §第 12 步
