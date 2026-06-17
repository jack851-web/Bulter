import 'package:flutter/material.dart';

import '../../ai/model_registry.dart';
import '../../components/bulter_scaffold.dart';
import '../../components/svg_icon.dart';
import '../../theme/tokens.dart';

/// 模型配置页。
///
/// 顶部：当前激活模型卡片
/// 中部：厂商选择（横向 chips）
/// 下部：API Key 输入（password）+ 模型下拉 + 保存 / 清除
class ModelConfigPage extends StatefulWidget {
  const ModelConfigPage({super.key});

  @override
  State<ModelConfigPage> createState() => _ModelConfigPageState();
}

class _ModelConfigPageState extends State<ModelConfigPage> {
  final _keyCtl = TextEditingController();
  late String _vendorId;
  late String _model;
  bool _obscure = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final reg = ModelRegistry.instance;
    final active = reg.active;
    _vendorId = active.vendorId;
    _model = active.model;
    _keyCtl.text = active.apiKey;
  }

  @override
  void dispose() {
    _keyCtl.dispose();
    super.dispose();
  }

  List<String> get _models => ModelRegistry.instance.modelsOf(_vendorId);

  void _onVendorChanged(String id) {
    setState(() {
      _vendorId = id;
      _model = ModelRegistry.instance.modelsOf(id).isNotEmpty
          ? ModelRegistry.instance.modelsOf(id).first
          : '';
      _keyCtl.text = ''; // 切厂商清空 Key 输入（避免误保存到错厂商）
      _saved = false;
    });
  }

  void _onModelChanged(String? m) {
    if (m == null) return;
    setState(() {
      _model = m;
      _saved = false;
    });
  }

  Future<void> _save() async {
    final reg = ModelRegistry.instance;
    final key = _keyCtl.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写 API Key')),
      );
      return;
    }
    await reg.saveApiKey(vendorId: _vendorId, apiKey: key);
    await reg.switchTo(vendorId: _vendorId, model: _model);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存。下次发送消息即生效。')),
    );
  }

  Future<void> _clear() async {
    await ModelRegistry.instance.clearApiKey(_vendorId);
    if (!mounted) return;
    setState(() {
      _keyCtl.text = '';
      _saved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除当前厂商的 API Key')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reg = ModelRegistry.instance;
    final active = reg.active;
    final vendors = reg.vendors;
    final models = _models;

    return BulterScaffold(
      title: '模型',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: BulterSpacing.s),
          // 1) 当前激活卡片
          _ActiveCard(
            vendor: active.vendorLabel,
            model: active.model,
            hasKey: active.apiKey.isNotEmpty,
          ),
          const SizedBox(height: BulterSpacing.l),

          // 2) 厂商选择
          const _SectionLabel('厂商'),
          const SizedBox(height: BulterSpacing.s),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vendors.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: BulterSpacing.s),
              itemBuilder: (_, i) {
                final v = vendors[i];
                final selected = v.id == _vendorId;
                return ChoiceChip(
                  label: Text(v.label),
                  selected: selected,
                  onSelected: (_) => _onVendorChanged(v.id),
                  backgroundColor: BulterColors.surface,
                  selectedColor: BulterColors.cta,
                  labelStyle: TextStyle(
                    color: selected
                        ? BulterColors.ctaText
                        : BulterColors.textPrimary,
                    fontSize: BulterFontSize.body,
                    fontWeight: BulterFontWeight.medium,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BulterRadius.pill),
                    side: BorderSide(
                      color: selected
                          ? BulterColors.cta
                          : BulterColors.divider,
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // 3) 模型下拉
          const SizedBox(height: BulterSpacing.l),
          const _SectionLabel('模型'),
          const SizedBox(height: BulterSpacing.s),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BulterSpacing.l,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: BulterColors.surface,
              borderRadius: BorderRadius.circular(BulterRadius.l),
              border: Border.all(color: BulterColors.divider, width: 0.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: models.contains(_model) ? _model : null,
                isExpanded: true,
                icon: const SvgIcon(
                  'common/chevron-down.svg',
                  size: 16,
                  color: BulterColors.textSecondary,
                ),
                items: [
                  for (final m in models)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: _onModelChanged,
              ),
            ),
          ),

          // 4) API Key
          const SizedBox(height: BulterSpacing.l),
          const _SectionLabel('API Key'),
          const SizedBox(height: BulterSpacing.s),
          Container(
            decoration: BoxDecoration(
              color: BulterColors.surface,
              borderRadius: BorderRadius.circular(BulterRadius.l),
              border: Border.all(color: BulterColors.divider, width: 0.5),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: BulterSpacing.l),
                  child: SvgIcon(
                    'settings/key.svg',
                    size: 18,
                    color: BulterColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _keyCtl,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      hintText: '在此粘贴你的 API Key',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (_) {
                      if (_saved) setState(() => _saved = false);
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: SvgIcon(
                    _obscure ? 'common/info.svg' : 'common/check.svg',
                    size: 18,
                    color: BulterColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 5) 操作按钮
          const SizedBox(height: BulterSpacing.l),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: BulterColors.cta,
                  borderRadius: BorderRadius.circular(BulterRadius.pill),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(BulterRadius.pill),
                    onTap: _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: BulterSpacing.m),
                      child: Center(
                        child: Text(
                          '保存',
                          style: TextStyle(
                            color: BulterColors.ctaText,
                            fontSize: BulterFontSize.body,
                            fontWeight: BulterFontWeight.semibold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: BulterSpacing.s),
              Material(
                color: BulterColors.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _clear,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SvgIcon(
                        'common/close.svg',
                        size: 18,
                        color: BulterColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: BulterSpacing.l),
          const _Hint(
            text:
                'Key 仅保存在本机 Hive 中，不会同步到云端。更换厂商后请重新填写。',
          ),
          const SizedBox(height: BulterSpacing.huge),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final String vendor;
  final String model;
  final bool hasKey;
  const _ActiveCard({
    required this.vendor,
    required this.model,
    required this.hasKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BulterSpacing.l),
      decoration: BoxDecoration(
        color: BulterColors.surface,
        borderRadius: BorderRadius.circular(BulterRadius.l),
        border: Border.all(color: BulterColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BulterColors.cta,
              borderRadius: BorderRadius.circular(BulterRadius.m),
            ),
            child: const Center(
              child: SvgIcon(
                'settings/model.svg',
                size: 22,
                color: BulterColors.ctaText,
              ),
            ),
          ),
          const SizedBox(width: BulterSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前激活',
                  style: TextStyle(
                    fontSize: BulterFontSize.caption,
                    color: BulterColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$vendor · $model',
                  style: const TextStyle(
                    fontSize: BulterFontSize.body,
                    fontWeight: BulterFontWeight.semibold,
                    color: BulterColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BulterSpacing.s,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: hasKey
                  ? BulterColors.success.withOpacity(0.12)
                  : BulterColors.warning.withOpacity(0.18),
              borderRadius: BorderRadius.circular(BulterRadius.pill),
            ),
            child: Text(
              hasKey ? '已配置' : '未配置',
              style: TextStyle(
                fontSize: BulterFontSize.caption,
                fontWeight: BulterFontWeight.semibold,
                color: hasKey
                    ? BulterColors.success
                    : BulterColors.wealth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: BulterSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: BulterFontSize.footnote,
          color: BulterColors.textSecondary,
          fontWeight: BulterFontWeight.semibold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BulterSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: BulterFontSize.footnote,
          color: BulterColors.textTertiary,
          height: 1.5,
        ),
      ),
    );
  }
}
