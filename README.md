# 悠gn追番助手

`悠gn追番助手` 是一个围绕 Bangumi 与 Notion 构建的 Flutter 追番工具，目标是把放送日历、每日推荐、条目搜索、详情查看、Notion 绑定和进度回写整合成一条顺手的日常追番工作流。

当前仓库目录名和 Dart 包名仍然保留为 `flutter_utools`，但应用对外展示名称已经统一为 `悠gn追番助手`。

## 当前能力

### 放送页

- 拉取 Bangumi 放送日历，仅展示动画条目
- 将 Notion 中已绑定的作品叠加到放送列表，并单独展示追番卡片
- 展示已追集数、最近更新、下次更新、最近观看时间、总集数进度等信息
- 在已绑定追番卡片中显示 `悠gn` 评分、`BGM` 评分和 `+1` 快捷操作
- 长按已绑定条目可将追番进度 `+1`，并尝试同步回 Notion 与 Bangumi

### 今日安利页

- 从 Notion 推荐库中筛选候选作品，默认条件为 `Yougn 评分 >= 6.5`
- 补全 Bangumi 评分、排名、封面、标签、制作人员和长评信息
- 展示评分分布、最近在看、最近看完等模块
- 支持从推荐页直接搜索 Notion 条目，或对最近在看条目执行 `+1`

### 搜索与详情

- 支持 Bangumi 搜索与 Notion 搜索两种来源
- 支持搜索历史、联想建议、列表/卡片视图切换和排序记忆
- Bangumi 详情页支持查看制作信息、评论和外部链接
- 支持把 Bangumi 条目导入到 Notion，或绑定到已有 Notion 页面

### 设置工作台

- Bangumi OAuth 授权登录、Token 状态检查、退出授权
- Notion Token / Database ID 配置与连接测试
- 字段映射页，支持 Magic Map 自动匹配、模块校验、草稿态编辑与显式保存
- 批量绑定页，扫描最近 30 条未绑定 Notion 条目并匹配 Bangumi
- 外观设置，包括主题模式、配色、动态取色、系统字体、系统标题栏、OLED 优化、评分显示
- 错误日志查看、复制和清空

### 缓存与持久化

- 敏感信息使用 `flutter_secure_storage`
- 常规设置与页面缓存使用 `shared_preferences`
- 当前已对放送页、推荐页、最近观看、批量绑定 UI 状态、错误日志等做了本地缓存

## 页面结构

当前主导航以 `NavigationRail / NavigationBar` 为核心，默认首页是放送页。

| 页面 | 作用 |
| --- | --- |
| 放送页 | 查看 Bangumi 放送日历与已绑定作品进度 |
| 推荐页 | 查看今日安利、评分统计、最近观看 |
| 搜索页 | 搜索 Bangumi 或 Notion 条目 |
| 设置页 | 授权、数据库配置、映射、批量绑定、外观、日志 |

设置页下目前包含这些主要入口：

- 账号与同步
- 数据绑定
- 数据映射
- 批量绑定
- 外观设置
- 错误日志

## 快速开始

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 准备 Notion 配置

仓库提供了示例文件 [`.env.example`](./.env.example)，你可以先复制一份：

```bash
cp .env.example .env
```

Windows PowerShell 可以直接使用：

```powershell
Copy-Item .env.example .env
```

最少需要配置：

```env
NOTION_TOKEN=your_notion_token_here
NOTION_DATABASE_ID=your_notion_database_id_here
```

你也可以在应用启动后通过“设置 -> 数据绑定”填写并保存这些内容。

### 3. 注入 Bangumi OAuth 配置并运行

直接通过 `--dart-define` 启动：

```bash
flutter run \
  --dart-define=BANGUMI_CLIENT_ID=your_client_id \
  --dart-define=BANGUMI_CLIENT_SECRET=your_client_secret
```

如果你已经把相关环境变量写入系统，也可以继续使用同样的命令，运行时环境变量会优先生效。

## 配置说明

### Notion 配置

应用启动时会尝试读取 `.env`，同时也会优先读取应用内已经保存的配置。

当前生效顺序可以理解为：

1. 先读取应用内已保存的设置
2. 如果为空，再回退读取 `.env`

主流程当前只要求这两个字段：

- `NOTION_TOKEN`
- `NOTION_DATABASE_ID`

### Bangumi OAuth 配置

Bangumi OAuth 使用固定回调地址：

```text
http://localhost:8080/auth/callback
```

请先在 Bangumi 开发者后台登记该回调地址：

- <https://bgm.tv/dev/app>

当前支持的配置项：

- `BANGUMI_CLIENT_ID`：必填
- `BANGUMI_CLIENT_SECRET`：推荐填写，代码层允许为空

代码中的读取优先级为：

1. 运行时操作系统环境变量
2. 编译期 `--dart-define`

### 平台说明

仓库保留了 Flutter 的多平台工程结构，但 Bangumi 本地回调授权当前是按桌面端实现的：

- 支持本地 OAuth 回调：Windows / macOS / Linux
- Web / Android / iOS 虽然可以构建工程，但当前这套本地回调登录流程并不完全适用

如果你的主要目标是使用 Bangumi 登录、映射、批量绑定和进度同步，建议优先使用桌面端。

## 推荐的初始化顺序

1. 启动应用
2. 在“设置 -> 数据绑定”里确认 `Notion Token` 与 `Database ID`
3. 在“设置 -> 数据映射”里完成字段映射，至少确保 `Bangumi ID`、标题等核心字段可用
4. 在“设置”页完成 Bangumi 授权登录
5. 根据你的使用方式选择：
   - 去“放送页”查看已绑定作品和当日放送
   - 去“推荐页”查看今日安利
   - 去“搜索页”单条导入或绑定
   - 去“批量绑定”补齐尚未绑定 Bangumi ID 的 Notion 页面

## 映射系统说明

当前映射系统已经不是早期的单层字段表，而是基于 `schema v2` 的模块化映射配置。

主要特点：

- 公共字段绑定 + 模块级覆盖
- 区分读取映射与写入映射
- 支持映射到 Notion 页面正文
- 支持 Magic Map 自动尝试匹配常见字段名
- 支持映射校验与旧配置迁移

目前主流程会依赖这些映射模块：

- 推荐读取
- 追番读取
- 追番写入
- 批量绑定
- 身份绑定

如果映射缺失，放送页、推荐页和批量绑定功能都会按模块给出提示。

## 批量绑定说明

批量绑定页当前工作流大致如下：

1. 读取 Notion 主数据库中最近 30 条尚未绑定 Bangumi ID 的页面
2. 使用页面标题调用 Bangumi 搜索
3. 为每条页面生成最多 3 个候选 Bangumi 条目
4. 支持一键绑定、批量绑定、手动输入 Bangumi ID 校验后绑定
5. 绑定时会打开导入对话框，允许继续选择要写入 Notion 的字段

当前还做了这些细节处理：

- 结果列表与 UI 选择状态会缓存
- `notionType` 命中漫画类型时会在批量候选中过滤掉
- 支持冲突展开、候选切换和跳过项目

## 搜索与同步细节

- Bangumi 搜索当前固定过滤为动画条目
- 放送页与推荐页中的进度 `+1` 会优先写回 Notion
- 如果已存在有效 Bangumi Token，也会额外尝试同步 Bangumi 追番进度
- 推荐页会补拉 Notion 页面正文中的长评与封面信息
- 详情页导入时可选择新建 Notion 页面，或绑定到已有页面

## 构建

### 直接使用 Flutter

```bash
flutter build windows \
  --dart-define=BANGUMI_CLIENT_ID=your_client_id \
  --dart-define=BANGUMI_CLIENT_SECRET=your_client_secret
```

### 使用仓库内构建脚本

仓库提供了 [`tool/build.dart`](./tool/build.dart)，它会读取系统环境变量中的：

- `BANGUMI_CLIENT_ID`
- `BANGUMI_CLIENT_SECRET`

然后自动拼接到 `flutter build` 参数中。

```bash
dart run tool/build.dart --platform windows --release
```

支持的平台参数：

```text
windows | macos | linux | android | ios | web
```

补充说明：

- `android` 会被映射为 `flutter build apk`
- 如果未设置 Bangumi 环境变量，脚本仍会继续构建，但会打印 warning 表示 OAuth 功能不可用

## 开发命令

```bash
flutter analyze
flutter test
```

## 项目结构

```text
lib/
  app/        应用级设置与服务装配
  config/     Bangumi OAuth 配置
  core/       网络、存储、主题、组件、映射基础设施
  features/   按业务拆分的页面、ViewModel、子模块
  models/     Bangumi / Notion / 映射相关模型

tool/
  build.dart  构建脚本

test/
  核心能力、布局、缓存、映射、构建脚本等测试

docs/
  产品文档、设计记录、迭代计划
```

## 主要依赖

- `http`
- `provider`
- `flutter_web_auth_2`
- `shared_preferences`
- `flutter_secure_storage`
- `flutter_dotenv`
- `url_launcher`
- `dynamic_color`
- `google_fonts`
- `cached_network_image`

## 目前需要注意的点

- Bangumi OAuth 本地回调当前以桌面端为主
- Bangumi 搜索固定为动画，不覆盖游戏、三次元等全部条目类型
- 批量绑定当前只扫描最近 30 条未绑定 Notion 条目
- 若映射未配置完整，推荐、放送、批量绑定等页面会进入提示态而不是直接工作

## 许可证

本项目基于 [Apache License 2.0](./LICENSE) 开源。
