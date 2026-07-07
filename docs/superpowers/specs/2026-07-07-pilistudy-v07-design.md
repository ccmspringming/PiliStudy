# PiliStudy v0.7 设计规格：家长控制、内容源与大屏基础优化

日期：2026-07-07
仓库：https://github.com/ccmspringming/PiliStudy
基线版本：v0.6 / commit `5d24253`

## 1. 背景与主要矛盾

v0.1-v0.6 已经完成学习首页、主题轮换刷新、折叠屏布局修复和 README 项目化。v0.7 的主要矛盾已经从“能不能刷出学习视频”转为：

> 家长要能控制内容边界，孩子要能顺畅观看学习内容，同时不能把上游 PiliPlus 播放能力改坏。

因此 v0.7 采取受控 MVP：在现有架构上增加一层“学习安全控制”，尽量少侵入播放器核心。

## 2. v0.7 范围

v0.7 包含四个方向：

1. 家长模式与本地 PIN。
2. 可自定义内容源与关键词白名单。
3. 默认隐藏或弱化评论、弹幕，保留相关推荐。
4. 安卓平板和安卓电视的基础使用优化。

v0.7 不做以下内容：

- 不做精确 BVID 课程库。
- 不做云端课程源同步。
- 不做 JSON 导入/导出。
- 不做完整 Android TV Leanback 首页。
- 不做强安全账户系统。
- 不移除相关推荐。

这些内容放到 v0.8 或后续版本。

## 3. 数据与存储设计

复用现有 Hive 设置盒 `GStorage.setting`，不增加 Hive adapter。

新增设置键建议放在 `lib/utils/storage_key.dart`：

- `studyParentPinHash`：家长 PIN hash。
- `studyParentPinSalt`：PIN salt。
- `studyContentSourceMode`：内容源模式。
- `studyCustomKeywords`：自定义关键词，多行字符串，一行一个。
- `studyWhitelistWords`：课程白名单词，多行字符串，一行一个。
- `studyExtraBlockWords`：额外屏蔽词，多行字符串，一行一个。
- `studyHideComments`：是否隐藏评论，默认 true。
- `studyDisableDanmaku`：是否关闭弹幕，默认 true。
- `studyLargeScreenMode`：大屏/遥控器优化开关，默认自动或 false。

PIN 只作为本地家长门槛，不宣传成强安全。项目已有 `crypto` 依赖时使用 `sha256(salt + pin)`；如果 CI 发现依赖不可用，则退回本地弱保护并在 UI 文案中明确说明。

## 4. 新增模块边界

避免继续膨胀 `lib/pages/study/view.dart`。

新增文件建议：

- `lib/pages/study/study_safety.dart`
  - 读取/写入学习安全设置。
  - 解析多行关键词。
  - 提供白名单、额外屏蔽词、内容源模式、PIN 校验工具。

- `lib/pages/study/parent_settings.dart`
  - 家长设置 UI。
  - PIN 设置/验证。
  - 内容源、白名单、屏蔽词、评论/弹幕开关、大屏优化开关。

StudyPage 只做集成：入口按钮、关键词来源、过滤逻辑和空状态提示。

## 5. 家长模式设计

### 5.1 入口

在 `PiliStudy 学习` 页面 AppBar 增加“家长设置”入口。

### 5.2 流程

- 未设置 PIN：首次点击入口时要求设置 4-6 位数字 PIN。
- 已设置 PIN：点击入口后输入 PIN，验证通过进入家长设置。
- 设置页中允许修改 PIN。

### 5.3 UI

家长设置页或弹窗包含：

- 内容源模式：
  - 内置主题
  - 自定义关键词
  - 内置 + 自定义
- 自定义关键词：多行输入，一行一个。
- 白名单关键词：多行输入，一行一个。
- 额外屏蔽词：多行输入，一行一个。
- 开关：
  - 隐藏评论，默认开启。
  - 关闭弹幕，默认开启。
  - 大屏/遥控器优化，默认关闭或自动。

## 6. 内容源与白名单设计

### 6.1 内容源模式

当前 StudyPage 有内置 `_allThemes`。v0.7 将内容源抽象为 active sources：

- 内置主题：只使用 `_allThemes`。
- 自定义关键词：只使用家长输入的关键词。
- 混合模式：内置主题 + 自定义关键词。

“全部”标签下拉刷新继续轮换 active sources。加载更多继续保持当前 source 翻页，不切 source。

### 6.2 自定义关键词为空时

如果选择“自定义关键词”但列表为空，学习页展示空状态：

> 当前未配置自定义内容源。请进入家长设置添加关键词，或切换为内置主题。

### 6.3 白名单过滤

过滤顺序：

1. 现有内置屏蔽词。
2. 家长额外屏蔽词。
3. 如果白名单为空：通过前两步即可展示。
4. 如果白名单非空：标题、简介、UP 主命中任一白名单词才展示。

白名单过严导致无结果时，空状态提示：

> 当前白名单过严，暂时没有匹配课程。请进入家长设置调整关键词或白名单。

## 7. 评论、弹幕与相关推荐

用户要求：隐藏或弱化评论、弹幕等，保留相关推荐。

### 7.1 评论

低风险入口是 `lib/pages/video/controller.dart` 中的 `showReply` getter。

v0.7 方案：

- 当 `StudySafetyPrefs.hideComments == true` 时，`showReply` 返回 false。
- 保留 `showRelatedVideo` 原逻辑，不关闭相关推荐。

这是全局学习版默认行为，不做“只对 StudyPage 打开的视频生效”的复杂路由状态。理由：PiliStudy 是儿童学习版，默认全局隐藏评论更简单、更稳定。

### 7.2 弹幕

优先选择中央偏好覆盖，而不是逐个 patch 弹幕 widget。

可选低风险位置：

- `Pref.enableShowDanmaku`
- `Pref.enableTapDm`
- 或播放器控制器中初始化弹幕开关的地方

v0.7 目标：

- 默认不显示弹幕。
- 默认不允许点击弹幕互动。
- 不影响视频播放本身。

StudyPage 卡片中可考虑去掉弹幕数展示，减少干扰，但不是强制项。

## 8. 平板与 Android TV 基础优化

### 8.1 平板

继续沿用 v0.6 的折叠屏/横屏网格策略，避免重构。

可做小改：

- 家长设置页在宽屏使用更宽的表单宽度。
- 关键按钮保留足够点击区域。
- 不破坏现有 `NavigationRail minWidth: 88`。

### 8.2 Android TV

v0.7 只做基础可用，不做完整 TV 版。

建议：

- 在 Android Manifest 增加 `android.hardware.touchscreen` 非必需声明，便于无触控设备安装。
- 不添加 Leanback launcher，避免缺少 banner 和 TV 商店要求导致新问题。
- 在学习页网格外层增加基础焦点遍历支持或保证卡片可 focus。
- 不承诺遥控器完整体验，只称为“大屏/遥控器基础优化”。

## 9. 验证计划

### 9.1 静态验证

- `git diff --check`
- changed-files guard：确认只改预期文件。
- grep 检查：
  - 新设置键存在。
  - 家长入口存在。
  - PIN 设置/校验存在。
  - 自定义关键词和白名单过滤存在。
  - `showReply` 受学习安全开关控制。
  - 弹幕显示/交互受学习安全开关控制。
  - v0.5 主题轮换仍存在。
  - v0.6 `NavigationRail minWidth: 88` 仍存在。

### 9.2 构建验证

本地环境缺少完整 Flutter/Android SDK 时，以 GitHub Actions 为准：

- 推送到 main。
- 等待 `PiliStudy Android APK` workflow 成功。
- 下载 artifact。
- 解压并校验 `app-debug.apk` SHA256。

### 9.3 人工测试清单

- 首次点击家长设置，能设置 PIN。
- 再次点击家长设置，需要输入 PIN。
- 自定义关键词模式下，“全部”标签按自定义关键词刷新。
- 白名单非空时，非命中内容被过滤。
- 白名单过严时，有明确空状态提示。
- 视频详情页不显示评论。
- 弹幕默认关闭，且弹幕点击互动不可用。
- 相关推荐仍显示。
- 折叠屏横置不回归 overflow。
- 视频卡片底部空白不回归。

## 10. 分阶段实现建议

为降低风险，v0.7 可以拆成两个 commit：

1. `feat: add parent controls and study content filters`
   - 存储键。
   - `study_safety.dart`。
   - `parent_settings.dart`。
   - StudyPage 集成内容源、白名单和家长入口。

2. `feat: apply study safety defaults to video playback`
   - 隐藏评论。
   - 默认关闭弹幕/弹幕互动。
   - Android TV 基础 manifest/focus 小优化。

最终只交付一个 v0.7 APK。

## 11. 成功标准

v0.7 成功的标准不是“功能很多”，而是：

- 家长能用 PIN 进入设置。
- 家长能配置自定义关键词和白名单。
- 学习页内容受这些设置控制。
- 评论和弹幕默认不打扰孩子。
- 相关推荐仍可用于学习延展。
- 平板/折叠屏不回归 v0.6 已修复的问题。
- GitHub Actions 成功产出 APK。
