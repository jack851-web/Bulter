/// 工作记忆：单次多步任务内的临时状态。
///
/// 设计：
/// - 每个"任务"（task）有自己的 key/value 工作区
/// - key/value 形如 `step=2`, `partial_sum=1280`, `category=dining`
/// - 当任务结束 / 用户切换话题 → 自动清空
/// - 工作记忆会作为 system prompt 的"附加段落"注入 LLM，
///   让 LLM 知道"我已经做过的中间步骤"（避免重复调用 / 跑题）
///
/// 存储在内存（不写 DB）；如需跨会话保留可后续扩展为 DB 表。
class WorkingMemory {
  final Map<String, String> _kv = {};
  String? _taskTitle;

  /// 是否有活跃任务。
  bool get hasActiveTask => _taskTitle != null;

  String? get taskTitle => _taskTitle;

  /// 当前任务的所有 kv 快照（不可变）。
  Map<String, String> get snapshot => Map.unmodifiable(_kv);

  /// 开始一个新任务（清空旧状态）。
  void startTask(String title) {
    _taskTitle = title;
    _kv.clear();
  }

  /// 设置一个 kv。覆盖已有值。
  void set(String key, String value) {
    if (_taskTitle == null) return;
    _kv[key] = value;
  }

  /// 读取一个 kv；缺失返回 null。
  String? get(String key) => _kv[key];

  /// 批量更新。
  void updateAll(Map<String, String> patch) {
    if (_taskTitle == null) return;
    _kv.addAll(patch);
  }

  /// 删除一个 kv。
  void remove(String key) {
    _kv.remove(key);
  }

  /// 结束当前任务并清空。
  void finishTask() {
    _taskTitle = null;
    _kv.clear();
  }

  /// 渲染为可注入 LLM 的段落；空状态返回 ''。
  String render() {
    if (_taskTitle == null || _kv.isEmpty) return '';
    final buf = StringBuffer('【当前任务】$_taskTitle\n');
    buf.writeln('【中间状态】');
    _kv.forEach((k, v) => buf.writeln('  - $k = $v'));
    return buf.toString();
  }
}
