# Bulter 技术文档

> 按"功能类别 → 所需技术 → 实现位置"组织。
> 技术栈：Flutter 3.24+ / Dart 3.5+ / Riverpod 2.5+ / go_router 14+ / Drift (SQLite) / Hive / sqlite-vec

---

## 〇、架构原则

在进入具体技术前，先明确几条核心原则，避免过度工程：

1. **Agent 问答 = 按需检索**。用户主动提问时，主模型通过 RAG + 工具 + `invoke_sub_agent` 当场检索回答，**不依赖预生成简报**。
2. **简报 = 被动浏览**。简报系统服务于"打开首页就想看各模块近期摘要"的场景，是**产品功能**，不是 Agent 调度核心。两者解耦。
3. **子模型用 API 级轻量模型**。不使用 7B 本地模型做工具调用（可靠性不足）；子模型选 DeepSeek-V3 / Qwen-Turbo / GPT-4o-mini 等 API 级轻量模型。
4. **工具隔离靠注册层**。子 agent 注册时就不注入写工具，不用运行时字符串匹配。
5. **不为不存在的并发做防御**。单用户本地 App 没有 CAS/乐观锁需求，简报用"最新覆盖旧"即可。

---

## 一、前端框架与状态管理

**负责功能**：全部 UI 渲染、路由、状态管理

| 技术 | 用途 |
|------|------|
| Flutter 3.24+ / Dart 3.5+ | 跨平台 UI 框架（iOS/Android/Web） |
| Riverpod 2.5+ | 状态管理（Provider/Notifier/AsyncNotifier） |
| go_router 14+ | 声明式路由（胶囊切换器 + 底部 Tab + 深链） |
| freezed + json_serializable | 不可变数据模型代码生成 |

**实现位置**：
- `lib/main.dart` — 应用入口、ProviderScope
- `lib/router/` — 路由配置
- `lib/providers/` — Riverpod Provider 定义
- `lib/models/` — freezed 数据模型

---

## 二、数据存储

**负责功能**：联系人、账单、读后感、健康记录、记忆等全部本地数据

| 技术 | 用途 |
|------|------|
| Drift | SQLite ORM，类型安全查询，支持 Stream 响应式更新 |
| sqlite3 | 本地数据库引擎 |
| Hive | 轻量 KV 存储（用户偏好、缓存、简报 JSON） |
| sqlite-vec | 向量存储与检索（RAG 语义记忆） |

**实现位置**：
- `lib/db/` — Drift 数据库定义、表结构、DAO
- `lib/db/tables/` — 各模块表定义
- `lib/db/dao/` — 各模块数据访问对象
- `lib/storage/` — Hive Box 配置

**核心表**：
- `contacts` / `interactions` / `favors` — 关系模块
- `goals` / `okrs` / `learning_records` / `projects` — 成长模块
- `accounts` / `transactions` / `budgets` — 财富模块
- `thoughts` / `letters` / `annual_reviews` — 思想模块
- `health_records` / `checkup_reports` / `health_scores` — 健康模块
- `messages` / `sessions` — AI 对话
- `briefings` — 模块简报（首页浏览用，见 §六）
- `embeddings` — 向量数据（sqlite-vec 虚拟表）
- `memories` / `user_profile` — 记忆系统

---

## 三、AI 调用

**负责功能**：AI 对话、场景推理、跨模块叙事

### 3.1 模型选型

| 角色 | 推荐模型 | 要求 |
|------|----------|------|
| 主模型 Orchestrator | MiniMax M3 / DeepSeek-V3 / Qwen-Max / Claude Sonnet | ≥30B API 级，原生多模态，工具调用稳定 |
| 子模型 Specialist | DeepSeek-V3 / Qwen-Turbo / GPT-4o-mini / Claude Haiku | API 级轻量模型，**必须支持稳定的 function calling** |

> 子模型统一用 API 级轻量模型，单次成本仍很低（约 ¥0.001-0.01/次），但工具调用可靠。

### 3.2 调用协议

采用 **OpenAI Chat Completions 兼容协议**（行业事实标准），支持流式 SSE：

```http
POST {base_url}/v1/chat/completions
Authorization: Bearer {api_key}

{
  "model": "MiniMax-M3",
  "messages": [...],
  "tools": [...],          // JSON Schema 工具定义
  "tool_choice": "auto",
  "stream": true
}
```

响应中 `delta.tool_calls` 携带工具调用，客户端执行后以 `role: "tool"` 消息回传，LLM 再生成总结性回复。这是标准的 Function Calling 多轮交互。

### 3.3 多模态

MiniMax M3 原生支持文本/图片/音频/视频，截图和语音走同一模型，无需独立 OCR / ASR：
- 截图：`image_url`（base64 WebP，长边 ≤1568px，≤2MB）
- 语音：先上传拿 `file_id`，以 `video_url` 传入

**实现位置**：
- `lib/ai/ai_service.dart` — AI 调用封装（streamCompletion，处理 SSE + tool_calls 分片累积）
- `lib/ai/model_registry.dart` — 模型配置注册表（9 厂商，能力自动探测）

---

## 四、工具系统（Tool Use）

**负责功能**：AI 调用本地工具读取/写入数据

### 4.1 工具调用标准流程

采用 OpenAI Function Calling 标准：

```
用户输入 → 构造 messages（system + 历史 + RAG 片段 + 工具列表）
  → 调用 LLM（流式）
  → LLM 返回文本 或 tool_calls
  → 客户端执行工具（读/写数据库）
  → 工具结果以 tool 消息回传 LLM
  → LLM 生成自然语言总结回复
```

一个意图可触发多轮工具调用（ReAct 范式：Thought→Action→Observation→…），直到 LLM 不再请求工具。

### 4.2 工具注册表

```dart
class ToolRegistry {
  final Map<String, Tool> _tools = {};
  final Map<String, ToolExecutor> _executors = {};
  
  void register({required Tool tool, required ToolExecutor executor}) { ... }
  List<Tool> getTools() => _tools.values.toList();
  Future<ToolResult> execute(String name, Map<String, dynamic> params) => ...;
}
```

### 4.3 工具隔离（注册层隔离）

> 不用运行时字符串前缀匹配（`contact_read_*`）做隔离，脆弱且难维护。改为**注册层隔离**——子 agent 创建时只注入它该用的工具，根本看不到写工具。

```dart
// 构建子 agent 时，只注册本模块只读工具 + RAG + briefing_publish
SpecialistAgent buildRelationSpecialist() {
  final registry = ToolRegistry();
  registry.register(tool: contactReadListTool, executor: ...);
  registry.register(tool: contactReadDetailTool, executor: ...);
  registry.register(tool: relationRagSearchTool, executor: ...);
  registry.register(tool: briefingPublishTool, executor: ...);
  // 不注册任何 save_/update_/delete_ 工具 → 子模型物理上无法调用
  return SpecialistAgent(tools: registry);
}
```

主模型注册全部工具（含写工具 + `invoke_sub_agent`）。这样隔离在构造时完成，无需运行时校验。

### 4.4 工具清单

| 工具名 | 角色 | 读/写 | 说明 |
|--------|------|-------|------|
| `save_contact` / `update_contact` / `delete_contact` | 主模型 | 写 | 关系 CRUD |
| `save_transaction` / `update_transaction` | 主模型 | 写 | 财富 CRUD |
| `save_thought` / `save_health_record` / `save_goal` | 主模型 | 写 | 各模块写 |
| `query_records` | 主模型 | 读 | 通用查询 |
| `rag_search` | 主/子 | 读 | 语义检索 |
| `invoke_sub_agent` | 主模型 | — | 调用子模型（仅主模型有） |
| `briefing_publish` | 子模型 | 写(简报) | 子模型唯一写权限，仅写简报 JSON |
| `delete_*` | 主模型 | 写 | **必须 pending_confirmation 二次确认** |

**实现位置**：
- `lib/ai/tools/tool_registry.dart`
- `lib/ai/tools/` — 各工具实现（read_*, write_*, rag_search, invoke_sub_agent, briefing_publish）

---

## 五、Agent 调度与多智能体

### 5.1 多智能体协作模式

```
用户提问
   │
   ▼
主模型 Orchestrator（API 级大模型）
   │
   ├─ 简单问题（单模块、明确）→ 直接用本地工具 + RAG 回答
   │
   └─ 跨模块/需深查 → invoke_sub_agent(module_id, query)
                          │
                          ▼
                    子模型 Specialist（API 级小模型）
                    当场用本模块工具 + RAG 检索
                    返回自然语言结果（不调写工具）
                          │
                          ▼
                    主模型汇总多个子模型结果
                    生成跨模块叙事回复
```

**关键点**：
- 子模型**当场按需检索**，不依赖预生成简报
- 子模型返回的是**自然语言结果**（不是工具调用），写操作权在主模型
- 主模型拿到子模型回复后，如需写操作，经 `pending_confirmation` 让用户确认

### 5.2 invoke_sub_agent 工具

```dart
Tool(
  name: 'invoke_sub_agent',
  description: '调用某模块子模型，让它基于本模块最新数据回答问题',
  parameters: {
    'type': 'object',
    'properties': {
      'module_id': {'type': 'string', 'enum': ['relation','growth','finance','thoughts','health']},
      'query': {'type': 'string', 'description': '发给子模型的问题'},
    },
    'required': ['module_id', 'query'],
  },
)
```

执行：主模型调用 → 取子模型 client → 发送 query + 本模块上下文 → 子模型用工具/RAG 检索 → 返回文本（丢弃任何 tool_call 字段，防幻觉）→ 超时 8s 降级。

### 5.3 主模型上下文注入

主模型每次对话前注入：
1. **用户画像**（始终注入，结构化）
2. **RAG 检索片段**（按当前 query 检索，Top-K）
3. **简报摘要（可选）**：首页已有最新简报时，可作为快速上下文让主模型了解各模块近期概况；但回答具体问题以 RAG + 工具为准
4. 短期对话历史（滑动窗口 20 轮）

**实现位置**：
- `lib/ai/orchestrator.dart` — 主模型调度
- `lib/ai/sub_agents/` — 各模块子模型（注册层隔离工具）
- `lib/ai/tools/invoke_sub_agent_tool.dart`
- `lib/ai/memory/memory_manager.dart` — 上下文注入

---

## 六、简报系统

### 6.1 定位

> **简报是"首页被动浏览"的产品功能，不是 Agent 调度核心。**

- **场景**：用户打开 App 首页，想看各模块近期有什么值得关注，**不主动问 AI**就能看到卡片摘要。
- **与 Agent 的关系**：简报服务于"打开就看"；Agent 对话服务于"主动提问"。主模型对话时可将简报作为**可选快速上下文**，但回答具体问题靠 RAG + 工具按需检索。
- **解耦**：简报生成失败不影响 Agent 对话；Agent 对话不依赖简报。

### 6.2 实现

**保留**：
- 定时生成（每日 23:00 / 每周日 22:00 / 每月最后一天 / 每年 12/31）
- 各模块子模型生成 `ModuleBriefing`（≤2KB）
- 首页卡片展示 `push_headline` + `summary`
- `generated_at` + `TTL` 判断新鲜度（过期则下次定时刷新，首页显示"更新于 X 小时前"）

**不做（过度工程）**：
- ~~CAS 乐观锁~~ — 单用户本地无并发，最新覆盖旧即可
- ~~version 版本号~~ — 不需要
- ~~4 位状态位 is_fresh~~ — 改为简单的 `generated_at + ttl` 时间比较
- ~~briefing_diff / 简报版本管理~~ — 首页只需最新一份，不存历史版本

### 6.3 数据结构

```dart
@freezed
class ModuleBriefing with _$ModuleBriefing {
  const factory ModuleBriefing({
    required String moduleId,         // 'relation' | 'growth' | ...
    required DateTime generatedAt,    // 生成时间
    required String period,           // 'daily' | 'weekly' | 'monthly' | 'yearly'
    required int ttlSeconds,          // 有效期
    required String pushHeadline,     // ≤30字符，首页卡片标题
    String? pushSubline,              // ≤50字符，副标题
    required String summary,          // ≤2000字符，详细摘要
    required List<BriefingRecommendation> recommendations,
  }) = _ModuleBriefing;
}
```

### 6.4 存储

简报 JSON 存 Hive（轻量 KV），一个模块一个 Box key，新值覆盖旧值。首页打开时读 5 份简报渲染卡片。

### 6.5 生成流程

```
定时触发（23:00）
   │
   ▼
Scheduler 并行唤醒 5 个子模型
   │
   ▼
每个子模型：读本模块近 N 天数据 + RAG → 生成 ModuleBriefing JSON
   │
   ▼
写入 Hive（覆盖旧值）→ 首页下次打开展示新简报
```

**实现位置**：
- `lib/ai/briefing/briefing_store.dart` — 简报读写（Hive）
- `lib/ai/briefing/briefing_generator.dart` — 简报生成（调子模型）
- `lib/ai/scheduler.dart` — 定时触发
- `lib/models/briefing.dart` — 数据模型

---

## 七、RAG 语义记忆

**负责功能**：跨会话长记忆、语义搜索、上下文注入

| 技术 | 用途 |
|------|------|
| sqlite-vec | 向量存储与 ANN 检索 |
| BGE-M3 / OpenAI text-embedding-3-small | Embedding 模型 |
| 自研 Reranker（可选 Cohere Rerank） | 重排序 |

**流程**：文档切分（按语义段落，重叠窗口）→ Embedding → 存入 sqlite-vec → 查询时向量化 → Top-K 召回 → Rerank → 注入主模型上下文。

**实现位置**：
- `lib/ai/rag/embedder.dart` — Embedding 生成
- `lib/ai/rag/vector_store.dart` — 向量存取（sqlite-vec）
- `lib/ai/rag/retriever.dart` — 检索器（Top-K + Rerank）
- `lib/ai/rag/context_injector.dart` — 上下文注入
- `lib/db/tables/embeddings.dart` — 向量虚拟表

> RAG 是 Agent 对话的**主检索方式**，简报仅作为首页浏览 + 可选快速上下文。

---

## 八、记忆系统四层架构

**负责功能**：会话记忆、任务记忆、长记忆、用户画像

| 层级 | 技术 | 用途 |
|------|------|------|
| Layer 1 短记忆 | 内存 List + Hive | 会话级上下文（当前对话历史，滑动窗口 20 轮） |
| Layer 2 工作记忆 | Hive | 任务态临时存储（多步任务的中间状态） |
| Layer 3 长记忆 | sqlite-vec + Drift | 跨会话 RAG 检索（事实/偏好/事件/关系/洞察/目标） |
| Layer 4 用户画像 | Drift | 长期稳定特征（姓名/职业/偏好/目标/重要他人） |

**记忆提取**：对话关闭时 / 每 N 条消息后，LLM 从对话中提取长记忆，向量去重合并写入。

**注入**：每次 LLM 调用前，用户画像始终注入 + RAG 检索相关长记忆注入。

**实现位置**：
- `lib/ai/memory/memory_manager.dart`
- `lib/ai/memory/short_term.dart` / `working.dart` / `long_term.dart` / `user_profile.dart`

---

## 九、输入路径

### 路径 A：浮窗截图

| 技术 | 用途 |
|------|------|
| Flutter Overlay API + 原生 AccessibilityService | 系统级浮窗（Android） |
| 截图插件 | 屏幕截图 |
| MiniMax M3 多模态 | 图像理解 + 场景推理 |

**实现位置**：
- `lib/overlay/overlay_service.dart` / `overlay_widget.dart`
- `lib/ai/scene_inference.dart` — 截图 → 模块归类
- `platform/floating_window.dart` / `screenshot.dart` — 原生桥接

### 路径 B：AI 对话

| 技术 | 用途 |
|------|------|
| dio SSE | 流式响应 |
| 自研聊天 UI | 消息气泡、打字机效果 |
| speech_to_text | 语音输入 |

**实现位置**：
- `lib/features/chat/` — 对话页、控制器、消息气泡

### 路径 C：手动录入

| 技术 | 用途 |
|------|------|
| Flutter Form | 结构化表单 |
| file_picker + csv | CSV 批量导入 |

**实现位置**：
- `lib/features/form/` — 各模块表单页

---

## 十、调度系统

**负责功能**：简报定时生成 + Agent 按需触发

| 调度类型 | 触发 | 技术 |
|----------|------|------|
| 简报定时 | 每日/每周/每月/每年 | workmanager 后台任务 + flutter_local_notifications |
| Agent 被动 | 浮窗截图 / AI 对话 / 主页打开 | Riverpod Provider 事件驱动 |

> 定时调度只负责简报生成（首页浏览用）；Agent 对话是纯事件驱动的按需调用，无定时。

**实现位置**：
- `lib/ai/scheduler.dart` — 简报定时任务
- `lib/ai/orchestrator.dart` — Agent 事件驱动调度

---

## 十一、跨模块联动

**负责功能**：模块间事件传递

| 技术 | 用途 |
|------|------|
| EventBus（发布订阅） | 7 类跨模块事件 |
| Riverpod Listener | 监听事件更新 UI |

**实现位置**：
- `lib/events/event_bus.dart` / `events.dart` / `handlers/`

---

## 十二、错误处理与监控

**负责功能**：AI 错误处理、熔断、监控

### 12.1 错误分类

| 类别 | 处理 |
|------|------|
| A 模型未响应（超时/网络/限流） | 重试 1 次（backoff 2s）→ 降级（用旧简报或提示"暂时无法获取"） |
| B 幻觉/越权（自造工具/越权调用） | 拒绝 + 带负面示例重试 1 次 |
| C 调用方式错误（Schema/参数错） | 不重试，报错修复 Schema |
| D 返回格式错误（JSON 不合法） | 容错提取 JSON → 重试 1 次 |

### 12.2 熔断器

连续失败 3 次 → 冷却 10min → 半开探测 1 次。子模型熔断时主模型降级为"该模块暂不可用"。

### 12.3 监控

错误率 / 延迟 / Token 成本 / 简报生成成功率。

**实现位置**：
- `lib/ai/error_handler.dart` / `circuit_breaker.dart` / `monitor.dart`

---

## 十三、成本估算

> 多智能体的价值是**聚焦和质量**，不是省钱。重度使用下多智能体往往更贵。

| 场景 | 调用次数 | 估算成本 |
|------|----------|----------|
| 一次普通对话（主模型 1 次 + 偶尔 1 子模型） | 1-2 次 API | ¥0.01-0.03 |
| 一次跨模块深查（主模型 + 2-3 子模型） | 3-4 次 API | ¥0.03-0.08 |
| 简报定时生成（每日 5 子模型 × 1 次） | 5 次/天 = 150 次/月 | ¥1-3/月 |
| 中度用户（日均 10 次对话 + 简报） | ~400 次/月 | ¥15-40/月 |
| 重度用户（日均 30 次 + 跨模块） | ~1200 次/月 | ¥50-120/月 |

**结论**：成本取决于使用强度。多智能体的真正收益是上下文聚焦（子模型只看本模块，Token 减少）和跨模块叙事质量，不是简单的"省钱"。

---

## 十四、反馈学习

**负责功能**：用户反馈采集 + 学习规则调整

| 技术 | 用途 |
|------|------|
| Drift | 反馈信号存储 |
| 自研 LearningEngine | 权重调整（简单贝叶斯/加权平均） |

6 类反馈信号（点赞/点踩/采纳/忽略/修改/分享）→ 5 条学习规则（调整推荐权重、TTL、简报优先级等）。

**实现位置**：
- `lib/ai/feedback/collector.dart` / `learning_engine.dart`

---

## 十五、UI 组件与设计系统

| 技术 | 用途 |
|------|------|
| flutter_svg | lucide 图标渲染 |
| google_fonts | Cal Sans 显示字体 |
| 自研 DesignToken | 色彩/间距/圆角/字体 token |

**实现位置**：
- `lib/theme/tokens.dart` — 6 模块品牌色、画布 #FAF6EE、CTA 纯黑
- `lib/components/` — module_card / briefing_card / ai_insight_card / fab_chat / capsule_switcher / bottom_tab

---

## 十六、Web 端

| 技术 | 用途 |
|------|------|
| Flutter Web | 同一套代码编译为 Web |
| LayoutBuilder | 桌面/平板/手机响应式 |
| graphview | 关系图谱可视化 |

**实现位置**：
- `lib/web/` — dashboard_screen / graph_screen

---

## 十七、安全与隐私

| 技术 | 用途 |
|------|------|
| flutter_secure_storage | API Key / 用户画像加密存储 |
| SQLCipher（可选） | SQLite 加密 |
| 自研 Desensitizer | AI 调用前脱敏（手机号/身份证/金额） |

- 本地优先，数据默认不上传
- 截图 AI 推理后自动删除原图，仅留缩略图
- 写操作（尤其删除）必须 pending_confirmation

**实现位置**：
- `lib/security/secure_storage.dart` / `desensitizer.dart` / `permissions.dart`

---

## 十八、项目目录结构

```
lib/
├── main.dart
├── router/
├── providers/
├── models/
├── theme/
├── components/
├── db/
│   ├── tables/
│   └── dao/
├── storage/                     # Hive Box
├── ai/
│   ├── ai_service.dart          # AI 调用（SSE + tool_calls）
│   ├── model_registry.dart      # 模型配置
│   ├── orchestrator.dart        # 主模型调度（多智能体）
│   ├── sub_agents/              # 子模型（注册层工具隔离）
│   ├── tools/                   # 工具系统
│   │   ├── tool_registry.dart
│   │   ├── read_*.dart          # 只读工具（主/子可用）
│   │   ├── write_*.dart         # 写工具（仅主模型注册）
│   │   ├── rag_search.dart
│   │   ├── invoke_sub_agent.dart
│   │   └── briefing_publish.dart
│   ├── briefing/                # 简报系统（首页浏览功能）
│   │   ├── briefing_store.dart
│   │   └── briefing_generator.dart
│   ├── rag/                     # RAG 语义记忆
│   ├── memory/                  # 4 层记忆
│   ├── scheduler.dart           # 简报定时调度
│   ├── error_handler.dart
│   ├── circuit_breaker.dart
│   ├── monitor.dart
│   └── feedback/
├── events/                      # 跨模块 EventBus
├── features/
│   ├── chat/                    # AI 对话
│   ├── form/                    # 手动录入
│   ├── relationship/ growth/ wealth/ thought/ health/
│   └── settings/
├── overlay/                     # 浮窗截图
├── platform/                    # 原生桥接
├── security/
└── web/
```
