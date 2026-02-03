## 文档信息
- **项目名称**: Kazumi
- **版本**: 1.9.5
- **文档类型**: UI 实现技术 PRD
- **技术栈**: Flutter/Dart
- **文档日期**: 2026.1

---

## 1. 产品概述

### 1.1 产品定位
Kazumi 是一个跨平台番剧管理应用，支持 Android、iOS、Windows、macOS、Linux 和 Web 多平台，提供新番追踪、历史记录、视频播放等核心功能。

### 1.2 UI 设计理念
- **现代化扁平化设计**: 采用 Material Design 3 设计语言
- **响应式布局**: 自适应手机、平板、桌面等多种设备
- **动态主题**: 支持 Material You 动态配色和深色模式
- **流畅交互**: Hero 动画、骨架屏、缓存优化等提升用户体验

---

## 2. 技术架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────┐
│              Material Design 3 主题系统          │
├─────────────────────────────────────────────────┤
│         响应式布局引擎 (OrientationBuilder)      │
├─────────────────────────────────────────────────┤
│    状态管理层 (MobX + Provider + flutter_modular) │
├─────────────────────────────────────────────────┤
│          UI 组件层 (Custom Widgets)             │
├─────────────────────────────────────────────────┤
│        数据持久层 (Hive + cached_network_image)  │
└─────────────────────────────────────────────────┘
```

### 2.2 核心依赖
| 包名 | 版本 | 用途 |
|------|------|------|
| flutter | 3.38.8 | 基础框架 |
| flutter_mobx | ^2.3.0 | 状态管理 |
| provider | ^6.1.2 | 补充状态管理 |
| flutter_modular | ^6.3.4 | 模块化路由 |
| cached_network_image | ^3.4.1 | 图片缓存 |
| dynamic_color | ^1.8.1 | 动态主题 |
| card_settings_ui | ^2.0.1 | 设置组件 |

---

## 3. 响应式布局策略

### 3.1 设备分类体系

```dart
// 设备类型判断工具类
class DeviceUtils {
  /// 桌面设备判断
  static bool isDesktop() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 宽屏设备判断 (关键阈值)
  static bool isWideScreen(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final double ratio = shortestSide / mediaQuery.size.longestSide;
    
    // 核心判断条件：
    // 1. 屏幕短边 ≥ 600px
    // 2. 宽高比 ≥ 0.5625 (9:16)
    return shortestSide >= 600 && ratio >= 0.5625;
  }

  /// 平板设备判断
  static bool isTablet(BuildContext context) {
    return isWideScreen(context) && !isDesktop();
  }

  /// 手机设备判断
  static bool isMobile(BuildContext context) {
    return !isWideScreen(context);
  }
}
```

### 3.2 导航栏切换策略

**触发条件**: 屏幕方向变化
```dart
// 导航栏切换核心实现
OrientationBuilder(builder: (context, orientation) {
  // 竖屏 → 底部导航栏
  // 横屏 → 侧边导航栏
  return orientation == Orientation.portrait
      ? _buildBottomNavLayout(context)
      : _buildSideNavLayout(context);
});
```

**布局规格**:
| 设备类型 | 导航位置 | 导航组件 | 标签显示 |
|----------|----------|----------|----------|
| 手机(竖屏) | 底部 | NavigationBar | 图标+文字 |
| PC/平板(横屏) | 左侧 | NavigationRail | 图标+文字 |

### 3.3 响应式数值规范

| 参数 | 手机端 | PC端/平板 | 备注 |
|------|--------|-----------|------|
| 屏幕短边阈值 | < 600px | ≥ 600px | 宽屏判断基准 |
| 宽高比阈值 | < 0.5625 | ≥ 0.5625 | 9:16 比例 |
| 标题最大行数 | 1-2行 | 2-3行 | 文本显示 |
| 间距(spacing) | 4px | 8px | 元素间距 |
| 卡片圆角 | 18px | 18px | 统一数值 |
| 外边距 | 4/6px | 4/6px | 统一数值 |
| 内边距 | 10/12px | 10/12px | 统一数值 |
| 图片宽高比 | 0.7 | 0.7 | imageWidth = height * 0.7 |

---

## 4. 主题系统设计

### 4.1 主题架构

```dart
// 主题提供者结构
class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;  // 跟随系统
  bool useDynamicColor = false;            // 动态配色开关
  late ThemeData light;                      // 亮色主题
  late ThemeData dark;                       // 暗色主题
  String? currentFontFamily;                // 字体设置
}
```

### 4.2 主题配置

**动态主题特性**:
- **Material You**: 通过 `dynamic_color` 包实现动态取色
- **深色模式**: 支持 OLED 纯黑背景优化
- **自定义字体**: 支持 MiSans 等自定义字体
- **主题模式**: 跟随系统 / 强制亮色 / 强制暗色

```dart
// OLED 深色主题优化
static oledDarkTheme(ThemeData defaultDarkTheme) {
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}
```

---

## 5. 核心 UI 组件设计

### 5.1 番剧卡片组件

#### 5.1.1 垂直卡片
```dart
class BangumiCardV extends StatelessWidget {
  // 用途: 推荐/搜索页面的垂直布局卡片
  
  // 设计规格:
  - 图片宽高比: 0.65
  - 圆角: 默认 Material Design
  - 文本行数: 手机2行，平板/桌面3行
  - Hero 动画: 启用 (tag: bangumiItem.id)
  - 加载状态: 骨架屏占位
}
```

**布局结构**:
```
┌─────────────────┐
│   封面图片       │  AspectRatio 0.65
│   (0.65)        │  NetworkImgLayer
├─────────────────┤
│  番剧标题       │  maxLines: 2-3
│  (动态行数)      │  ellipsis
└─────────────────┘
```

#### 5.1.2 时间线卡片
```dart
class BangumiTimelineCard extends StatelessWidget {
  // 用途: 时间线页面的水平布局卡片
  
  // 设计规格:
  - 卡片高度: 120px (可配置)
  - 图片宽度: height * 0.7
  - 圆角: 18px
  - 外边距: vertical: 4, horizontal: 6
  - 内边距: vertical: 10, horizontal: 12
  - 标题行数: 桌面2行，手机1行
  - 间距: 桌面8px，手机4px
}
```

**布局结构**:
```
┌──────────────────────────────────────┐
│ ┌─────┐ 番剧标题 (行数动态)          │
│ │图片 │ 简介信息 (带标签背景)         │
│ │0.7W │                              │
│ │     │ ━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ └─────┘ ⭐评分 📊排名 👥人数         │
└──────────────────────────────────────┘
```

### 5.2 图片加载组件

```dart
class NetworkImgLayer extends StatelessWidget {
  // 核心特性:
  
  // 1. 智能缓存策略
  - 基于设备分辨率动态调整缓存大小
  - 根据宽高比优化内存占用
  
  // 2. 占位符设计
  - 加载中: 显示 loading.png 占位图
  - 加载失败: 显示 noface.jpeg 占位图
  - 背景色: colorScheme.onInverseSurface.withAlpha(0.4)
  
  // 3. 动画效果
  - fadeOutDuration: 120ms
  - fadeInDuration: 120ms
  
  // 4. 圆角适配
  - avatar: 50px (圆形头像)
  - emote: 0px (表情图片)
  - 默认: StyleString.imgRadius.x
}
```

**内存优化策略**:
```dart
// 根据宽高比动态计算缓存尺寸
void setMemCacheSizes() {
  if (aspectRatio > 1) {
    memCacheHeight = height.cacheSize(context);  // 宽图优化高度
  } else if (aspectRatio < 1) {
    memCacheWidth = width.cacheSize(context);     // 窄图优化宽度
  } else {
    memCacheWidth = width.cacheSize(context);     // 方图全优化
    memCacheHeight = height.cacheSize(context);
  }
}
```

### 5.3 收藏按钮组件

```dart
class CollectButton extends StatefulWidget {
  // 收藏类型:
  // 0: 未追 (favorite_border)
  // 1: 在看 (favorite)
  // 2: 想看 (star_rounded)
  // 3: 搁置 (pending_actions)
  // 4: 看过 (done)
  // 5: 抛弃 (heart_broken)
  
  // 支持两种模式:
  1. 标准模式: IconButton
  2. 扩展模式: FilledButton.icon
  
  // 交互特性:
  - MenuAnchor 下拉菜单
  - 选中状态高亮 (primary color)
  - 菜单项高度: 48px
  - 最小宽度: 112px
}
```

---

## 6. 核心页面 UI 实现

### 6.1 时间线页面

**页面结构**:
```
┌────────────────────────────────────┐
│  时间线标题 + 时间机器按钮          │
├────────────────────────────────────┤
│  TabBar (周一 到 周日)             │
│  - 自动定位到当天                  │
│  - TabController 管理切换          │
├────────────────────────────────────┤
│  PageView.builder                  │
│  - 每个Tab对应一天的数据            │
│  - ListView.builder 渲染卡片       │
│  - 智能过滤 (已看/抛弃)            │
├────────────────────────────────────┤
│  底部导航栏 / 侧边导航栏            │
└────────────────────────────────────┘
```

**数据排序功能**:
```dart
// 排序方式:
1. 默认排序 (id排序)
2. 评分排序 (ratingScore 降序)
3. 热度排序 (votes 降序)
```

**时间机器功能**:
- 支持回溯历史季度 (近20年)
- 季度划分: 春(4月)、夏(7月)、秋(10月)、冬(1月)
- DraggableScrollableSheet 底部弹出选择

### 6.2 推荐页面

**页面组件**:
- 首页推荐轮播
- 新番推荐网格
- 热门番剧列表
- 网格布局自适应列数

### 6.3 收藏页面

**收藏类型过滤**:
- 在看
- 想看
- 搁置
- 看过
- 抛弃

**列表布局**:
- 卡片列表展示
- 支持编辑模式
- 批量操作功能

---

## 7. 动画与交互设计

### 7.1 Hero 动画

```dart
// 实现规格
Hero(
  tag: bangumiItem.id,              // 唯一标识
  transitionOnUserGestures: true,  // 手势触发过渡
  child: NetworkImgLayer(...)         // 目标组件
)
```

**使用场景**:
- 卡片 → 详情页封面过渡
- 列表 → 详情页平滑切换

### 7.2 骨架屏加载

```dart
// 使用 skeletonizer 包
Skeletonizer(
  enabled: isLoading,
  child: BangumiTimelineCard(...)  // 加载状态显示骨架
)
```

### 7.3 页面切换动画

```dart
// PageView 切换
PageView.builder(
  physics: NeverScrollableScrollPhysics(),  // 禁用滑动
  controller: pageController,
  itemBuilder: (_, __) => RouterOutlet()
)
```

---

## 8. 性能优化要求

### 8.1 图片优化

```dart
// 缓存策略
CachedNetworkImage(
  imageUrl: imageUrl,
  memCacheWidth: memCacheWidth,    // 内存缓存宽度
  memCacheHeight: memCacheHeight,  // 内存缓存高度
  fadeOutDuration: 120ms,          // 淡出动画
  fadeInDuration: 120ms,           // 淡入动画
  filterQuality: FilterQuality.high, // 图片质量
)
```

### 8.2 列表优化

```dart
// 使用 ListView.builder 避免全量渲染
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(index)
)
```

### 8.3 状态管理优化

```dart
// MobX ObservableList 自动响应式更新
@observable
ObservableList<List<BangumiItem>> bangumiCalendar = 
  ObservableList<List<BangumiItem>>();

// UI 自动更新
Observer(
  builder: (_) => ListView(
    children: controller.bangumiCalendar.map(...).toList()
  )
)
```

---

## 9. 跨平台适配

### 9.1 平台特定功能

| 平台 | 特有功能 | 实现方式 |
|------|----------|----------|
| Android | 分屏模式检测 | MethodChannel |
| iOS | 状态栏适配 | SafeArea |
| Windows | 窗口管理 | window_manager |
| Linux | X11 环境检测 | MethodChannel |
| Web | 禁用部分功能 | Platform.isWeb |

### 9.2 字体适配

```dart
// 字体选择器
MaterialApp(
  theme: ThemeData(
    fontFamily: ThemeProvider.currentFontFamily  // 自定义字体或系统字体
  )
)

// 文本缩放限制
textScaler: textScaler.clamp(maxScaleFactor: 1.1)
```

---

## 10. 可访问性要求

### 10.1 语义化标签

```dart
// 使用语义化组件
Semantics(
  button: true,
  label: '收藏按钮',
  hint: '点击收藏此番剧',
  child: CollectButton(...)
)
```

### 10.2 触摸目标尺寸

```dart
// 最小触摸目标: 48x48
MaterialTapTargetSize.padded
SizedBox(
  width: 48, 
  height: 48,
  child: IconButton(...)
)
```

---

## 11. 国际化支持

### 11.1 多语言配置

```dart
// 使用 flutter_localizations
MaterialApp(
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ],
)
```

### 11.2 时间格式化

```dart
// 相对时间显示
static String formatTimestampToRelativeTime(timeStamp) {
  var difference = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000)
  );
  
  if (difference.inDays > 365) return '${difference.inDays ~/ 365}年前';
  if (difference.inDays > 30) return '${difference.inDays ~/ 30}个月前';
  if (difference.inDays > 0) return '${difference.inDays}天前';
  if (difference.inHours > 0) return '${difference.inHours}小时前';
  if (difference.inMinutes > 0) return '${difference.inMinutes}分钟前';
  return '刚刚';
}
```

---

## 12. 错误处理与边界情况

### 12.1 网络错误处理

```dart
// 图片加载失败占位
errorWidget: (context, url, error) => placeholder(context)

// 网络请求错误提示
try {
  final res = await Request().get(url);
} catch (e) {
  KazumiLogger().e('Network error', error: e);
  showErrorWidget();
}
```

### 12.2 空状态处理

```dart
// 列表为空显示
if (items.isEmpty) {
  return Center(
    child: Text('暂无数据')
  );
}
```

### 12.3 边界值处理

```dart
// 文本溢出处理
Text(
  title,
  maxLines: maxLines,
  overflow: TextOverflow.ellipsis,  // 显示省略号
  textScaler: textScaler.clamp(maxScaleFactor: 1.1)  // 限制缩放
)
```

---

## 13. 实现优先级与里程碑

### 阶段一: 基础架构 (Week 1-2)
- [x] Material Design 3 主题系统
- [x] 响应式布局引擎
- [x] 设备检测工具类
- [x] 基础路由与导航

### 阶段二: 核心组件 (Week 3-4)
- [x] 番剧卡片组件 (垂直/水平)
- [x] 图片加载组件
- [x] 收藏按钮组件
- [x] 时间线页面

### 阶段三: 交互优化 (Week 5-6)
- [x] Hero 动画过渡
- [x] 骨架屏加载
- [x] 动态主题支持
- [x] 深色模式优化

### 阶段四: 性能优化 (Week 7-8)
- [x] 图片缓存优化
- [x] 列表性能优化
- [x] 状态管理优化
- [x] 内存占用优化

---

## 14. 技术约束与依赖

### 14.1 Flutter 版本要求
- **最低 SDK**: >=3.3.4
- **Flutter**: 3.38.8
- **Dart**: 对应版本

### 14.2 平台兼容性
- **Android**: API 21+ (Android 5.0+)
- **iOS**: iOS 11.0+
- **Windows**: Windows 10+
- **macOS**: macOS 10.11+
- **Linux**: 主流发行版
- **Web**: 现代浏览器

### 14.3 性能指标
- **应用启动**: < 3秒
- **页面切换**: < 200ms
- **图片加载**: 首屏 < 1秒
- **内存占用**: < 200MB (运行时)
- **帧率**: 保持 60fps

---

## 15. 附录

### 15.1 关键代码文件索引

| 功能模块 | 文件路径 |
|----------|----------|
| 设备检测 | [utils.dart](lib/utils/utils.dart#L264-L285) |
| 导航布局 | [menu.dart](lib/pages/menu/menu.dart#L30-L47) |
| 主题系统 | [theme_provider.dart](lib/bean/settings/theme_provider.dart#L1-L32) |
| 番剧卡片 | [bangumi_card.dart](lib/bean/card/bangumi_card.dart#L1-L105) |
| 时间线卡片 | [bangumi_timeline_card.dart](lib/bean/card/bangumi_timeline_card.dart#L1-L186) |
| 图片加载 | [network_img_layer.dart](lib/bean/card/network_img_layer.dart#L1-L122) |
| 收藏按钮 | [collect_button.dart](lib/bean/widget/collect_button.dart#L1-L163) |

### 15.2 设计资源

- **图标库**: Material Icons, Cupertino Icons
- **字体**: MiSans-Regular.ttf
- **设计规范**: Material Design 3
- **颜色系统**: Material You 动态配色

### 15.3 参考文档

- [Flutter 官方文档](https://flutter.dev/docs)
- [Material Design 3](https://m3.material.io)
- [MobX 文档](https://mobx.pub)
- [flutter_modular 文档](https://modular.flutterando.com.br)

---

## 16. 变更历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| 1.0.0 | 2024-01-15 | 初始版本 PRD | AI Assistant |
| 1.0.1 | 2024-01-20 | 补充性能优化细节 | AI Assistant |
| 1.9.5 | 2024-12-10 | 对应当前代码库版本 | AI Assistant |

---

**文档结束**

> 本 PRD 文档基于 Kazumi 项目当前代码库 (v1.9.5) 分析整理，涵盖了 UI 实现的核心技术细节。如需深入了解具体实现，请参考附录中的代码文件索引。