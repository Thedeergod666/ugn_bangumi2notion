的ui是怎么做的，用了哪些框架之类的？

GLM 4.7

用户询问 Kazumi 的 UI 是怎么做的，使用了哪些框架。这是一个关于项目技术栈的问题。

我需要查看项目的依赖配置文件来给你准确的答案。

文件查看完成

pubspec.yaml

好的，我已经看到了 pubspec.yaml 文件的内容。现在我可以看到 Kazumi 项目使用的各种框架和依赖。让我整理一下与 UI 相关的主要框架：

结构获取完成

lib

好的，现在我有了足够的信息来回答用户的问题。让我整理一下 Kazumi 的 UI 技术栈：

Kazumi 的 UI 技术栈挺典型的，就是 Flutter 那一套，但加了不少自研组件。让我给你梳理一下：

## 核心框架

**基础架构**

- **Flutter** - 整个应用的基础框架
- **flutter_modular** - 模块化架构，负责路由和依赖注入，代码组织得挺清晰，见 app_module.dartL1-L1
- **MobX** + **flutter_mobx** - 主要的状态管理方案
- **Provider** - 补充的状态管理，在某些场景使用

## UI 组件库

**Material Design 基础**

- 使用 Flutter 自带的 Material Design 组件
- **cupertino_icons** - iOS 风格图标，让跨平台体验统一
- **flutter_localizations** - 国际化支持

**第三方 UI 库**

- **card_settings_ui** - 设置页面的专用组件库，简化了设置界面的开发
- **dynamic_color** - 支持 Material You 的动态颜色，可以根据壁纸自动调整主题，见 theme_provider.dartL1-L1
- **flutter_rating_bar** - 评分条组件
- **scrollview_observer** - 滚动视图的监听和联动效果
- **skeletonizer** - 骨架屏加载动画，提升用户体验
- **fl_chart** - 图表组件，用于数据可视化

## 自研组件体系

从目录结构看，他们自己封装了不少组件：

**卡片类**（[bean/card/](https://github.com/Predidit/Kazumi/blob/master/lib/bean/card/))

- 番剧卡片、历史卡片、时间线卡片等
- 评论卡片、人物卡片、角色卡片

**UI 辅助**（[bean/widget/](https://github.com/Predidit/Kazumi/blob/master/lib/bean/widget/)）

- 收藏按钮、下拉菜单、错误提示组件

**弹幕系统**

- **canvas_danmaku** - 使用 Canvas 渲染弹幕，性能应该不错

## 图片与资源

- **cached_network_image** - 网络图片的缓存管理
- **flutter_svg** - SVG 矢量图支持
- 自定义字体：MiSans-Regular.ttf（国产字体，看着挺现代）
- GLSL 着色器：assets/shaders/ 用于 Anime4K 超分辨率效果

## 主题与样式

动态主题系统是亮点，支持：

- Material You 自动配色
- 自定义主题色
- 深色/浅色模式切换

整体风格走的是现代扁平化设计，带点 Material Design 的影子，但融入了不少自定义元素。代码组织也挺规范，页面、组件、模块分离得挺清楚。

想深入看某个组件的实现，可以从 bean/card/bangumi_card.dartL1-L1 或 pages/index_page.dartL1-L1 开始。

想了解更多技术细节：  
[使用 flutter_modular 的模块化架构](https://zread.ai/Predidit/Kazumi/9-modular-architecture-with-flutter_modular)  
[使用 MobX 进行状态管理](https://zread.ai/Predidit/Kazumi/10-state-management-with-mobx)  
[弹幕渲染系统](https://zread.ai/Predidit/Kazumi/23-danmaku-rendering-with-canvas_danmaku)

kazumi的新番放送页是怎么做的

GLM 4.7

用户问Kazumi的新番放送页是怎么做的。我需要查看相关代码，特别是时间线相关的页面。

已查看文件大纲

lib/pages/timeline/timeline_page.dart

已查看文件大纲

lib/pages/timeline/timeline_controller.dart

已查看文件大纲

lib/bean/card/bangumi_timeline_card.dart

看起来这些文件不是dart文件，或者类型不对。让我直接查看文件内容。

文件查看完成

lib/pages/timeline/timeline_page.dart

文件查看完成

lib/pages/timeline/timeline_controller.dart

好的，现在我看到了时间线页面的核心代码。让我也看看卡片组件的实现。

文件查看完成

lib/bean/card/bangumi_timeline_card.dart

文件查看完成

lib/request/bangumi.dart

好的，现在我看到了新番放送页面的实现细节。让我整理一下：

Kazumi的新番放送页（时间线页面）做得挺优雅的，是一个经典的分层架构设计。让我拆解给你看：

## 架构设计

**MVC + MobX 模式**

- **View层**：TimelinePageL1-L1 - UI展示
- **Controller层**：TimelineControllerL1-L1 - 业务逻辑和状态管理
- **Model层**：BangumiItemL1-L1 - 数据模型

## 核心实现

### 1. 数据获取

两种数据源策略：

- **当前时间线**：用 `getCalendar()` 直接从 bangumi calendar API 获取稳定数据
- **历史时间线**：用 `getCalendarBySearch()` 通过搜索API按季度分页获取（每次20部，最多4次请求）

```
// 核心数据结构ObservableList<List<BangumiItem>> bangumiCalendar = ObservableList<List<BangumiItem>>();// 7天的数据，每天一个列表
```

### 2. UI结构

**TabBar 顶部导航**（timeline_page.dart#L83-L91）

```
final List<Tab> tabs = const <Tab>[  Tab(text: '一'),  // 周一到周日  Tab(text: '二'),  // ...];
```

自动定位到今天是星期几：

```
int weekday = DateTime.now().weekday - 1;  // 0-6 对应周一到周日tabController = TabController(  vsync: this,   length: tabs.length,   initialIndex: weekday);
```

**时间机器功能**（timeline_page.dart#L67-L183）

- 可以回溯历史季度查看番剧
- 底部弹出 `DraggableScrollableSheet` 选择年/季
- 支持"时间旅行"到过去的季度

### 3. 数据处理

**排序方式**（timeline_controller.dart#L82-L103）

```
void changeSortType(int type) {  switch (sortType) {    case 1:  // 默认排序      dayList.sort((a, b) => a.id.compareTo(b.id));      break;    case 2:  // 评分排序      dayList.sort((a, b) => b.ratingScore.compareTo(a.ratingScore));      break;    case 3:  // 热度排序      dayList.sort((a, b) => b.votes.compareTo(a.votes));      break;  }}
```

**智能过滤**

- 不显示"放弃"的番剧（通过收藏状态判断）
- 不显示"已看完"的番剧
- 过滤存储在本地数据库（Hive）中

### 4. 卡片组件

BangumiTimelineCardL1-L1 的设计亮点：

**响应式布局**

```
final double imageWidth = cardHeight * 0.7;  // 图片宽高比固定final double borderRadius = 18;
```

**Hero 动画过渡**

```
if (enableHero) {  img = Hero(    tag: bangumiItem.id,    transitionOnUserGestures: true,    child: ClipRRect(...)  );}
```

**信息展示优先级**

1. 标题（优先中文，回退到原名）
2. 简介信息（带淡色背景的Tag样式）
3. 评分/排名/人数（右对齐的元数据）

## 技术细节

### 状态管理

- **MobX ObservableList** - 自动响应式更新UI
- **@observable + @action** - 标准的MobX模式

### 网络请求

- **Dio** - HTTP客户端
- **重试机制** - 最多4次分页请求历史数据
- **容错处理** - try-catch保证单个数据解析失败不影响整体

### 性能优化

- **图片缓存** - NetworkImgLayer 集成 cached_network_image
- **Hero动画** - 页面切换的流畅体验
- **懒加载** - ListView.builder 动态渲染

### 季度处理

AnimeSeason 类自动计算季度起止：

```
DateTime generateDateTime(int year, String season) {  switch (season) {    case '冬': return DateTime(year, 1, 1);    case '春': return DateTime(year, 4, 1);    case '夏': return DateTime(year, 7, 1);    case '秋': return DateTime(year, 10, 1);  }}
```

## 整体特点

1. **用户友好** - 自动定位到今天，支持"时间机器"回溯
2. **数据准确** - 两种API策略互补，确保数据完整性
3. **个性化** - 多种排序方式 + 智能过滤
4. **性能优化** - MobX响应式 + 图片缓存 + Hero动画
5. **代码清晰** - 分层架构，职责明确

这种实现方式既保证了用户体验，又维护了代码的可维护性。想看具体某个细节的实现，可以继续深入对应文件。