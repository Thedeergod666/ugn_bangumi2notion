# Flutter UTools 重构摘要

## 1. 现状功能梳理（基于当前代码）
- 导航结构：`NavigationShell` 使用侧边 NavigationRail + 路由（/calendar、/recommendation、/search、/mapping、/settings）。
- 放送页：从 Bangumi 拉取放送日历，按星期过滤；可标记已绑定番剧并展示“已追/已更/总集数”；支持已绑定横向列表；点击进入详情页。
- 推荐页：从 Notion 获取 6.5+ 的每日推荐，支持缓存与轮播；展示 Bangumi 详情、评分分布、长评；提供 Notion 搜索入口。
- 搜索页：Bangumi/Notion 双源搜索；Bangumi 结果跳转详情；Notion 结果可打开外链。
- 详情页：拉取 Bangumi 详情与评论；支持导入/更新 Notion（字段选择、标签选择、身份绑定）。
- 映射页：已改为“按应用模块配置”的统一映射页；字段采用通用槽位池（一次配置、多处复用），并显示模块使用去向与模块级校验。
- 设置页：Bangumi OAuth 授权、Notion Token/DB 设置、外观设置、错误日志等。

## 2. 目标架构（Clean Architecture + MVVM）
- 分层：
  - Data：API/Storage（BangumiApi、NotionApi、SettingsStorage）
  - Domain：实体与业务模型（Bangumi/Notion/Mapping）
  - Presentation：UI + ViewModel（每个页面一个 ViewModel，减少 Fat Widget）
- 依赖方式：通过 Provider 注入 ViewModel，UI 仅负责渲染和轻量交互。
- 统一状态管理：页面状态与异步请求集中在 ViewModel，减少 setState 分散。

## 3. 关键页面需求（来自产品构想）
### 放送页
- 追番模块：横向卡片（已绑定番剧）+ 追番进度展示；点击可更新 Notion 已追集数。
- 放送模块：周一到周日标签 + 日期提示；已绑定数量提示；视图切换（列表/画廊/瀑布流）。
- 绑定状态：已绑定番剧置顶，并显示“已绑定”标签。

### 推荐页
- 每日推荐：默认 3 条轮播展示（20s 轮换），支持“换一部”。
- 双容器布局：左侧封面+基础信息，右侧排名卡片/长评切换。
- 最近观看：优先展示在看，已看按时间排序，支持更新进度同步。

### 搜索页
- 搜索历史、搜索建议、筛选（最佳适配/热度/收藏）。
- 结果视图切换：画廊/列表。
- 详情页导入/更新 Notion，支持更新策略与标签控制。

### 设置页
- 映射设置：以应用需求为主导的模块化配置（导入写入、推荐读取、追番读写、身份绑定、搜索/批量导入），支持关键字段校验与影响范围可视化。
- 数据绑定：Notion/Bangumi 配置。
- 外观设置：主题、配色、动态配色、OLED 等。
- 侧边栏推荐卡片：宽屏显示今日推荐 + 换一部按钮；窄屏精简展示。

## 4. UI/跨平台适配策略
- 断点：
  - 窄屏（< 720）→ 底部导航栏
  - 中屏（720–1100）→ 折叠侧边栏
  - 宽屏（≥ 1100）→ 展开侧边栏 + 推荐卡片
- 页面布局：
  - 放送列表宽屏支持多列卡片；窄屏回落为列表。
  - 推荐模块宽屏左右分栏；中/窄屏上下布局。
  - 搜索结果宽屏支持网格；窄屏列表。

## 5. 本次重构落地范围
- 引入 `ViewModel`：Calendar/Mapping/Search（推荐/详情/设置后续逐步迁移）。
- 引入响应式断点工具，统一跨平台布局。
- 映射页重构（已落地）：
  - 统一模型 `MappingConfig V2`：`commonBindings + moduleOverrides + moduleParams`，`schemaVersion=2`
  - 一次性迁移：旧 `mappingConfig + dailyRecommendationBindings` 自动迁移并覆盖落盘；冲突优先级 `watchBindings > dailyBindings > old config`
  - 模块分组 UI：取消 Bangumi/Notion 双页签，按业务模块展示字段槽位
  - 通用字段池：标题、Bangumi ID、封面等只配置一次，多模块自动复用
  - 模块校验：关键槽位缺失时允许保存，但仅阻断受影响模块
  - 字段复用可视化：展示“字段使用去向”
  - `Magic Map` 升级：自动匹配结果直接写入 V2 槽位
  - 业务读取统一：推荐页/放送页/批量导入/搜索/详情通过 `MappingResolver` 解析字段
- 映射页入口调整：从导航移入设置页。

> 注：搜索历史/筛选、批量导入等高级功能在本次重构中保留为后续迭代项。
