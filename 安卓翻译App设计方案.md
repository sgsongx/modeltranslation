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
- 结果悬浮窗支持：查看、复制、关闭

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
   - 调 `OverlayGateway.showResult()` 显示悬浮窗  
   - 调 `RecordRepository.save()` 落库  
7. 失败：  
   - 悬浮窗展示错误摘要与重试入口  
   - 记录失败状态（便于排障与统计）

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
  - id, provider, baseUrl, apiKeyRef, model, temperature, topP, maxTokens, timeoutMs, systemPrompt, updatedAt
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

---

如果你需要，我可以下一步直接给出“开发级设计稿”版本：包含接口定义（Dart/Kotlin）、数据库表结构 SQL、以及事件协议字段清单。