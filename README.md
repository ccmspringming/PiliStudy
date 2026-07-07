<div align="center">
  <img width="160" height="160" src="assets/images/logo/logo.png" alt="PiliStudy logo">

  <h1>PiliStudy 学生学习版</h1>

  <p>基于 PiliPlus fork 改造的学生/儿童向 B 站学习客户端。</p>

  <p>
    <a href="https://github.com/ccmspringming/PiliStudy/actions/workflows/pilistudy-android.yml">
      <img src="https://github.com/ccmspringming/PiliStudy/actions/workflows/pilistudy-android.yml/badge.svg" alt="Android APK Build">
    </a>
    <img src="https://img.shields.io/github/repo-size/ccmspringming/PiliStudy" alt="repo size">
    <img src="https://img.shields.io/github/license/ccmspringming/PiliStudy" alt="license">
  </p>
</div>

## 项目定位

PiliStudy 不是从零开发的新客户端，而是在 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 基础上做的学习版改造。

目标很简单：把 B 站客户端从“泛娱乐入口”改造成“儿童/学生学习入口”。

当前版本优先解决三个问题：

- 让孩子打开 App 后先看到学习内容，而不是娱乐推荐流。
- 按年级和学科组织内容，降低搜索和筛选成本。
- 保留 B 站账号登录、播放、收藏、历史等基础能力，避免推倒重来。

## 核心功能

### 学习首页

- 默认进入 `PiliStudy 学习` 页面。
- 年级标签：启蒙教育、一年级、二年级、三年级、四年级、五年级、六年级。
- 学科筛选：全部、语文、数学、英语、阅读、科普、思维。
- 视频卡片展示封面、标题、时长、播放量、日期和 UP 主。

### “全部”标签主题轮换

“全部”标签不再反复请求同一个搜索词。

下拉刷新会在多个学习主题之间轮换，例如：

- 综合学习
- 科学实验
- 语文阅读
- 数学思维
- 英语启蒙
- 历史地理
- 纪录片
- 手工美育

这样可以避免“刷新了但还是同一批视频”的问题。

### 内容过滤

学习首页对搜索结果做基础黑名单过滤，尽量屏蔽明显不适合学习场景的内容，例如：

- 游戏
- 直播
- 鬼畜
- 恐怖
- 恋爱八卦
- 带货
- 擦边内容

注意：关键词过滤只是第一道防线，不等于严格的儿童安全白名单。长期给孩子使用，后续仍建议增加家长密码、白名单课程库和更强的内容审核机制。

### 登录保留

- 保留 B 站账号登录能力。
- 登录入口移动到“我的 / 家长登录”。
- 继续复用 PiliPlus 的播放、登录、收藏、历史等基础能力。

### 导航收敛

当前主导航收敛为：

- 学习
- 我的

动态、泛娱乐首页等入口被隐藏，减少孩子从学习内容跑偏的概率。

## 当前进度

当前主线版本：v0.6

关键改动：

- v0.1：完成 PiliStudy MVP，新增学习首页，保留登录入口，完成 Android APK CI 构建。
- v0.2：改进学习页内容缓存、刷新体验和安全区域适配。
- v0.3：增加横屏支持、滚动分页和内容自动补足。
- v0.4：重构网格布局，增强折叠屏和横屏适配。
- v0.5：重写“全部”标签刷新机制，改为多主题轮换，底部增加显式“加载更多”。
- v0.6：收紧视频卡片布局，减少底部空白；加宽侧边导航，修复折叠屏横置 overflow。

## APK 下载

目前 APK 通过 GitHub Actions 自动构建。

下载方式：

1. 打开 [Actions 页面](https://github.com/ccmspringming/PiliStudy/actions/workflows/pilistudy-android.yml)。
2. 选择最新一次成功的 `PiliStudy Android APK` workflow。
3. 在页面底部 `Artifacts` 下载 `PiliStudy-debug-apk`。
4. 解压后安装其中的 `app-debug.apk`。

说明：当前主要产物是 debug APK，适合测试和验证。后续如果要长期使用，建议增加正式签名 release APK。

## 本地构建

如果要本地构建 Android APK：

```bash
flutter --version
flutter pub get
flutter build apk --release --split-per-abi --android-project-arg dev=1 --pub
```

构建产物通常位于：

```text
build/app/outputs/flutter-apk/
```

本项目也提供 GitHub Actions workflow：

```text
.github/workflows/pilistudy-android.yml
```

用于自动构建 Android debug APK。

## 技术改造摘要

主要改动集中在：

- `lib/pages/study/view.dart`：新增学习首页、年级/学科筛选、主题轮换刷新、学习内容过滤。
- `lib/pages/main/view.dart`：导航收敛为学习/我的，并适配折叠屏侧边导航。
- `lib/models/common/nav_bar_config.dart`：调整主导航配置。
- `lib/common/constants.dart`：应用名称改为 `PiliStudy`。
- Android 包名改为 `com.example.pilistudy`，避免与原 PiliPlus 冲突。

## 后续计划

优先级从高到低：

- 增加家长密码或家长模式。
- 增加课程白名单和更可控的内容源。
- 进一步隐藏或弱化评论、相关推荐、弹幕发送等非学习入口。
- 增加正式 release APK 构建和签名。
- 增加截图、使用说明和安装教程。

## 注意事项

- 本项目仍依赖 B 站公开接口和上游 PiliPlus 能力。
- 学习内容来自搜索结果，不保证每条内容都完全适合儿童。
- 请家长结合实际情况使用，不建议完全无人监管。
- 当前包名为 `com.example.pilistudy`，可以和原 PiliPlus 并存安装。

## 协议与声明

本项目继承上游项目协议，继续遵守 GPL-3.0。

本项目仅用于学习、研究和测试。所用 API 来自公开网络资料和官方客户端行为分析，不提供破解内容，不绕过付费或权限限制。

请遵守 B 站相关服务条款和当地法律法规。

## 致谢

感谢以下开源项目和资料：

- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- [PiliPalaX](https://github.com/orz12/PiliPalaX)
- [pilipala](https://github.com/guozhigq/pilipala)
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [media-kit](https://github.com/media-kit/media-kit)
- Flutter 生态中的相关开源依赖

感谢原作者和社区的开源工作。PiliStudy 是在这些工作基础上的定向学习版改造。
