# PiliStudy 学生学习版

PiliStudy 是基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) fork 改造的学生学习版 B 站第三方客户端。

## 改造目标

- 首页直接进入学习频道，而不是泛娱乐推荐流。
- 按“启蒙教育、一年级、二年级、三年级、四年级、五年级、六年级”组织内容。
- 按“全部、语文、数学、英语、阅读、科普、思维”筛选课程。
- 保留 B 站账号登录能力，登录入口放在“我的/家长登录”中。
- 隐藏动态入口和首页搜索入口，降低儿童从学习内容跑偏的概率。
- 复用 PiliPlus 原有播放、登录、收藏、历史等能力。

## 当前 MVP 功能

- `lib/pages/study/view.dart`：新增学习首页。
- 学习首页使用 B 站搜索 API 拉取年级/科目关键词结果。
- 对搜索结果执行基础黑名单过滤，屏蔽游戏、直播、鬼畜、恐怖、恋爱等非学习内容。
- App 名称改为 `PiliStudy`。
- Android 包名改为 `com.example.pilistudy`，避免与原 PiliPlus 冲突。
- 底部/侧边导航收敛为“学习”和“我的”。

## 构建 APK

推荐使用 Flutter 项目指定版本：

```bash
flutter --version
flutter pub get
flutter build apk --release --split-per-abi --android-project-arg dev=1 --pub
```

构建产物通常位于：

```text
build/app/outputs/flutter-apk/
```

## 注意事项

- 关键词过滤不是绝对安全机制，只是第一道防线。长期给儿童使用，建议后续增加白名单课程库和家长密码。
- 视频详情页仍复用 PiliPlus 原播放页，后续应继续隐藏评论、相关推荐、弹幕发送等入口。
- 原项目采用 GPL-3.0 协议，本 fork/改造版继续遵守 GPL-3.0。
