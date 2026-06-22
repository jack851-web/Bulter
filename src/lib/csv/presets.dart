import 'csv_models.dart';

/// 预设 CSV 格式（Step 12）。
///
/// **支付宝账单导出**（支付宝 APP → 账单 → 开具交易流水证明 → CSV）：
/// - 必含列：交易号 / 商家订单号 / 交易创建时间 / 付款时间 / 交易对方 / 商品名称 / 金额
/// - 编码：GBK
///
/// **微信账单导出**（微信支付 → 账单 → 常见问题 → 下载账单 → CSV）：
/// - 必含列：交易单号 / 商户单号 / 交易时间 / 交易类型 / 交易对方 / 商品 / 金额(元)
/// - 编码：UTF-8
class CsvPresets {
  CsvPresets._();

  static final List<CsvPreset> all = [
    AlipayBillPreset(),
    WechatBillPreset(),
  ];
}

/// 支付宝账单。
class AlipayBillPreset extends CsvPreset {
  @override
  String get name => '支付宝账单';

  @override
  CsvModule get module => CsvModule.wealth;

  @override
  String get signatureHeader => '交易号';

  @override
  List<CsvFieldMapping> get defaultMapping => [
        const CsvFieldMapping(columnName: '交易号', field: null),
        const CsvFieldMapping(columnName: '商家订单号', field: null),
        const CsvFieldMapping(columnName: '交易创建时间', field: CsvField.date),
        const CsvFieldMapping(columnName: '付款时间', field: null),
        const CsvFieldMapping(columnName: '最近修改时间', field: null),
        const CsvFieldMapping(columnName: '交易来源地', field: null),
        const CsvFieldMapping(columnName: '类型', field: CsvField.type),
        const CsvFieldMapping(columnName: '交易对方', field: CsvField.counterparty),
        const CsvFieldMapping(columnName: '商品名称', field: CsvField.note),
        const CsvFieldMapping(columnName: '金额（元）', field: CsvField.amount),
        const CsvFieldMapping(columnName: '收/支', field: null),
        const CsvFieldMapping(columnName: '交易状态', field: null),
        const CsvFieldMapping(columnName: '服务费（元）', field: null),
        const CsvFieldMapping(columnName: '成功退款（元）', field: null),
        const CsvFieldMapping(columnName: '备注', field: null),
      ];
}

/// 微信账单。
class WechatBillPreset extends CsvPreset {
  @override
  String get name => '微信账单';

  @override
  CsvModule get module => CsvModule.wealth;

  @override
  String get signatureHeader => '交易单号';

  @override
  List<CsvFieldMapping> get defaultMapping => [
        const CsvFieldMapping(columnName: '交易单号', field: null),
        const CsvFieldMapping(columnName: '商户单号', field: null),
        const CsvFieldMapping(columnName: '商户名称', field: null),
        const CsvFieldMapping(columnName: '交易类型', field: CsvField.type),
        const CsvFieldMapping(columnName: '交易对方', field: CsvField.counterparty),
        const CsvFieldMapping(columnName: '商品', field: CsvField.note),
        const CsvFieldMapping(columnName: '金额(元)', field: CsvField.amount),
        const CsvFieldMapping(columnName: '收/支', field: null),
        const CsvFieldMapping(columnName: '交易时间', field: CsvField.date),
        const CsvFieldMapping(columnName: '支付方式', field: CsvField.account),
        const CsvFieldMapping(columnName: '当前状态', field: null),
        const CsvFieldMapping(columnName: '交易备注', field: null),
      ];
}
