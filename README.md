# flutter_utools

一个 Flutter 跨平台小工具：
- 从 **Bangumi (bgm.tv)** 搜索/查看动画条目
- 通过 **Bangumi OAuth2** 获取访问令牌
- 将条目详情按“字段映射”同步到 **Notion 数据库**（支持创建/更新页面，并可追加简介正文 Block）

> 说明：该仓库最初 README 为 Flutter 模板，本 README 基于当前代码实现补全。

## 功能概览

- Bangumi 动画搜索（类型固定为“动画”）
- 条目详情展示
- Notion 数据库属性读取/缓存
- 可配置字段映射（Bangumi -> Notion 属性名）
- 一键导入到 Notion：
  - 不存在则创建页面
  - 已存在则更新页面属性
  - 可选把简介写入页面正文（Block children）

相关实现：
- Bangumi 请求：[`lib/services/bangumi_api.dart`](lib/services/bangumi_api.dart:1)
- Bangumi OAuth：[`lib/services/bangumi_oauth.dart`](lib/services/bangumi_oauth.dart:1)
- Notion 同步：[`lib/services/notion_api.dart`](lib/services/notion_api.dart:1)
- 映射配置模型：[`lib/models/mapping_config.dart`](lib/models/mapping_config.dart:1)

## 页面与导航

应用使用侧边栏 + 命名路由切换主要页面：

- 搜索页：[`lib/screens/search_page.dart`](lib/screens/search_page.dart:1)
- 详情页：[`lib/screens/detail_page.dart`](lib/screens/detail_page.dart:1)
- 映射页：[`lib/screens/mapping_page.dart`](lib/screens/mapping_page.dart:1)
- 设置页：[`lib/screens/settings_page.dart`](lib/screens/settings_page.dart:1)

入口与路由：[`lib/main.dart`](lib/main.dart:1)

## 配置（必须）

项目使用 [`flutter_dotenv`](pubspec.yaml:40) 从 `.env` 读取第三方凭据；请按以下步骤配置：

1. 复制示例文件：

   - 将 [`.env.example`](.env.example:1) 复制为 `.env`

2. 填写 `.env`：

   **Bangumi OAuth（必填）**

   - `BANGUMI_APP_ID`
   - `BANGUMI_APP_SECRET`

   **Notion（必填）**

   - `NOTION_TOKEN`
   - `NOTION_DATABASE_ID`

3. Bangumi 回调地址（必须在后台注册）：

   - Windows 固定回调：`http://localhost:61390`
   - 非 Windows 回调：`bangumi-importer://oauth2redirect`

> `.env` 已被 [`.gitignore`](.gitignore:46) 忽略，避免误提交。

## 运行与构建

```bash
flutter pub get
flutter run
```

其他常用命令：

```bash
flutter test
flutter analyze
```

支持的平台（由 Flutter 工程结构决定）：Android / iOS / Web / Windows / macOS / Linux。

## 数据同步逻辑（简述）

- 在搜索页通过 [`BangumiApi.search()`](lib/services/bangumi_api.dart:14) 获取条目列表
- 进入详情页后通过 [`BangumiApi.fetchDetail()`](lib/services/bangumi_api.dart:46) 获取完整详情
- 点击“导入到 Notion”时：
  - 读取用户的 [`MappingConfig`](lib/models/mapping_config.dart:1)
  - Notion 侧通过 [`NotionApi.findPageByBangumiId()`](lib/services/notion_api.dart:99) 查询是否已存在
  - 通过 [`NotionApi.createAnimePage()`](lib/services/notion_api.dart:162) 创建/更新页面
  - 如映射配置启用正文写入，则通过 [`NotionApi.appendBlockChildren()`](lib/services/notion_api.dart:137) 追加简介

配置与 token 等持久化：[`lib/services/settings_storage.dart`](lib/services/settings_storage.dart:1)

## 依赖摘要

主要依赖见 [`pubspec.yaml`](pubspec.yaml:1)：

- `http`：网络请求
- `flutter_web_auth_2`：OAuth2 授权回调
- `shared_preferences`：本地持久化（设置/Token/映射）
- `flutter_dotenv`：加载 `.env`
- `url_launcher`：打开外部链接

## 许可证

未在仓库中声明许可证（如需开源发布请补充）。
