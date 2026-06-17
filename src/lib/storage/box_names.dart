/// Bulter Hive Box 名称与 versionId 集中管理。
///
/// 升级 Box 时通过 `Hive.openBox<T>(name, bytes: ..., encryptionCipher: ...)`
/// + `Box.migrate(...)` 处理结构变化。详见 `lib/storage/storage_init.dart`。
class BulterBoxes {
  BulterBoxes._();

  // 命名规范：bulter_{scope}_{purpose}
  static const String userPreferences =
      'bulter_user_preferences'; // 用户偏好（API Key、主题等）
  static const String briefingsCache = 'bulter_briefings'; // 简报 JSON 缓存
  static const String sessionsCache = 'bulter_sessions'; // 会话元数据缓存
  static const String demoKv = 'bulter_demo_kv'; // Demo 模块 KV 验证

  // 全部 Box 的 versionId 必须显式声明；升级时如不匹配需要 migrate。
  static const Map<String, int> versionIds = {
    userPreferences: 1,
    briefingsCache: 1,
    sessionsCache: 1,
    demoKv: 1,
  };
}
