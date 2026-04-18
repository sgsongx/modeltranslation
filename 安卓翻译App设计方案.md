# 安卓翻译 App 设计方案（Flutter + 可扩展悬浮球）

## 1. 项目目标
构建一个基于 Flutter 的安卓翻译 App，满足以下核心能力：

1. 通过 API 接入大模型，并提供参数配置菜单  
2. 提供系统级悬浮球，单击后读取剪切板文本并触发翻译  
3. 将翻译结果以悬浮窗口展示  
4. 翻译记录本地存储，并可便捷查看历史  

设计重点：低耦合、清晰数据流、悬浮球能力可扩展。

---

## 2. 功能范围与拆分

## 2.1 模型接入与配置中心
- 支持 OpenAI 兼容 API（可扩展到多供应商）
- 配置项：
  - Base URL
  - API Key（安全存储）
  - Model
  - Temperature / TopP / MaxTokens / Timeout
  - System Prompt（翻译风格）
- 支持连接测试与默认模板（如中英互译预设）

## 2.2 悬浮球与悬浮窗
- 全局悬浮球常驻（前台服务 + Overlay）
- 单击动作：`translate_clipboard`
- 长按动作：`open_recent_history`（快速查看最近 3 条翻译）
- 结果悬浮窗支持：查看原文、查看译文、复制、关闭
- 历史悬浮窗支持：滚动浏览、复制原文、复制译文、关闭
- 悬浮窗字体大小支持配置（12~28sp）并持久化存储

### 2.2.1 悬浮球交互细则（便捷 + 人性化）
- 单击：立即翻译剪切板（保持原有最快路径）
- 长按：显示“历史悬浮窗”，可直接浏览完整历史（无需切换到 App 主界面）
- 历史展示规则：按时间倒序展示全部可用记录，支持滚动浏览
- 每条历史提供快捷按钮：`Copy original` 与 `Copy translation`
- 空历史提示：`No translation history yet. Tap the bubble once to translate first.`
- 失败兜底：历史加载失败时展示错误摘要，不阻断悬浮球继续使用
- 背景切换策略：从悬浮球触发时自动回到后台，减少界面打断
- 触觉反馈：默认关闭（决策 4.B）
- 布局约束：悬浮窗采用“固定最大高度 + 内容滚动 + 底部操作栏固定”，保证 `Close` 按钮始终可见

## 2.3 翻译处理链路
- 读取剪切板文本
- 文本校验（空文本、过长、重复触发）
- 调用 LLM 翻译
- 结果展示 + 落库

## 2.4 历史记录
- 本地持久化翻译记录（原文、译文、参数快照、时间、状态）
- 历史列表、搜索、详情页、复制
- 删除单条/清空历史

---

## 3. 架构设计（低耦合）

采用 **Clean Architecture + 平台能力桥接**：

- Presentation 层：设置页、历史页、详情页、状态管理
- Application 层：用例编排（翻译、保存、查询）
- Domain 层：实体与接口（不依赖 Flutter/Android）
- Infrastructure 层：网络、数据库、安全存储、平台桥接
- Android Native 层：悬浮球服务、悬浮窗、剪切板访问
- Bridge 层：MethodChannel/EventChannel

核心原则：
- 业务逻辑不直接依赖平台细节
- 悬浮球只负责“触发动作”，不耦合翻译实现
- 模型供应商可插拔，数据存储可替换

---

## 4. 悬浮球扩展机制（关键）

定义统一动作协议（Action Registry）：

- `actionId`
- `triggerType`（click / longPress / doubleClick）
- `enabled`
- `execute(context) -> ActionResult`

初始动作：`translate_clipboard`  
新增动作：`open_recent_history`（长按触发）
后续新增（无需改主链路）：`summarize_clipboard`、`rewrite_clipboard`、`ocr_translate`。

这保证悬浮球能力“可持续扩展”，避免单点逻辑膨胀。

---

## 5. 数据流链路（端到端）

用户单击悬浮球后：

1. OverlayService 捕获点击事件  
2. 通过 EventChannel 发出 `onAction("translate_clipboard")`  
3. Flutter Application 层执行 `TranslateClipboardUseCase`  
4. 读取剪切板文本 -> 参数校验 -> 获取当前模型配置  
5. 调用 `LlmGateway.translate()`  
6. 成功：  
  - 调 `OverlayGateway.showResult()` 显示悬浮窗（含原文+译文结构化负载）  
   - 调 `RecordRepository.save()` 落库  
7. 失败：  
   - 悬浮窗展示错误摘要与重试入口  
   - 记录失败状态（便于排障与统计）

用户长按悬浮球后：

1. OverlayService 捕获长按事件
2. 通过 EventChannel 发出 `onAction("open_recent_history")`
3. Flutter Application/Presentation 层加载历史记录（按时间倒序）
4. 组装结构化历史负载（sourceText / translatedText / createdAt / status）
5. 调 `OverlayGateway.showResult()` 展示“Recent History”悬浮窗（附带字体大小配置）
6. 在悬浮窗内完成记录复制与回填，无需跳转 History 页

---

## 6. 核心模块职责

- `ConfigModule`
  - 管理 LLM 配置、模板预设、连通性测试
- `FloatingModule`
  - 悬浮球生命周期、动作注册、事件派发
- `TranslationModule`
  - 翻译请求构建、参数治理、错误重试
- `OverlayResultModule`
  - 结果悬浮窗 UI 与交互
- `HistoryModule`
  - 本地存储、检索、详情展示
- `SecurityModule`
  - API Key 加密读写

---

## 7. 数据模型（建议）

- `LlmConfig`
  - id, provider, baseUrl, apiKeyRef, model, temperature, topP, maxTokens, timeoutMs, systemPrompt, overlayFontSizeSp, updatedAt
- `TranslationRequest`
  - sourceText, sourceLang?, targetLang, stylePreset, configSnapshot
- `TranslationRecord`
  - id, sourceText, translatedText, provider, model, paramsJson, status, errorMessage, createdAt
- `ActionEvent`（可选）
  - id, actionId, payloadJson, resultStatus, createdAt

---

## 8. 技术选型建议

- Flutter 状态管理：Riverpod（推荐）
- 网络：Dio + 重试拦截器
- 本地数据库：Drift(SQLite)
- 安全存储：flutter_secure_storage
- 平台桥接：MethodChannel + EventChannel
- Android 原生：Kotlin + Foreground Service + Overlay

---

## 9. 异常与边界处理

- 无悬浮窗权限：引导授权页 + 一键跳转设置
- 剪切板为空：轻提示，不发请求
- 网络超时/API 失败：展示失败原因 + 重试
- 重复文本短时间触发：去抖与幂等策略
- 数据库存储失败：不影响结果展示，后台告警日志
- 长按时历史为空：给出引导文案而非报错
- 长按时历史加载失败：展示错误摘要并允许用户继续单击翻译
- 历史条目过多：悬浮窗内部滚动浏览，避免遮挡主画面
- 历史条目过多：底部操作栏固定，关闭按钮不随内容滚动
- MIUI 等系统限制：Overlay addView 失败时给出可见提示，避免“静默失败”

---

## 10. 非功能要求

- 性能：普通文本翻译链路尽量控制在 1~2 秒（网络正常）
- 安全：API Key 不明文存储；日志脱敏
- 可维护性：模块内聚、跨层接口清晰、单元测试覆盖核心用例
- 可扩展性：新增动作和新增模型供应商不改主流程

---

## 11. 迭代计划（MVP -> 增强）

1. MVP  
- 模型配置、悬浮球单击翻译、结果悬浮窗、历史记录

2. 增强版  
- 预设模板、重试策略、历史搜索、复制优化

3. 扩展版  
- 多动作中心、多供应商适配、统计看板、导出历史

---

## 12. 验收标准

1. 单击悬浮球可稳定读取剪切板并完成翻译展示  
2. 模型参数修改后即时生效，连接测试可用  
3. 每次翻译都有记录可查询（成功/失败均可追踪）  
4. 异常路径有清晰反馈，不出现“无响应”  
5. 新增动作时无需修改翻译核心用例代码
6. 长按悬浮球可在 1 次操作内查看最近历史，空状态有明确引导
7. 历史悬浮窗在大量数据下仍可关闭，不出现按钮越界
8. 可在设置页调整悬浮窗字体并在重启后保持生效
9. 历史悬浮窗支持一键复制原文/译文，结果悬浮窗同时展示原文与译文

---

如果你需要，我可以下一步直接给出“开发级设计稿”版本：包含接口定义（Dart/Kotlin）、数据库表结构 SQL、以及事件协议字段清单。