import 'dart:async';

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/pages/study/parent_settings.dart';
import 'package:PiliPlus/pages/study/study_safety.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _gradeController;
  final Map<String, _StudyCacheEntry> _cache = {};
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  int _subjectIndex = 0;
  int _allThemeIndex = 0;
  int _requestId = 0;
  int _currentPage = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _autoFillScheduled = false;
  int _emptyPageCount = 0;
  int _autoFillCount = 0;
  String? _error;
  List<SearchVideoItemModel> _items = const [];

  static const Duration _cacheTtl = Duration(minutes: 10);
  static const Duration _tabDebounce = Duration(milliseconds: 350);
  static const int _minBufferedItems = 12;
  static const int _maxAutoFillPages = 3;
  static const double _gridPadding = 8;
  static const double _gridSpacing = 8;

  static const List<_StudyGrade> _grades = [
    _StudyGrade('启蒙教育', '启蒙教育'),
    _StudyGrade('一年级', '一年级'),
    _StudyGrade('二年级', '二年级'),
    _StudyGrade('三年级', '三年级'),
    _StudyGrade('四年级', '四年级'),
    _StudyGrade('五年级', '五年级'),
    _StudyGrade('六年级', '六年级'),
  ];

  static const List<_StudySubject> _subjects = [
    _StudySubject('全部', ''),
    _StudySubject('语文', '语文'),
    _StudySubject('数学', '数学'),
    _StudySubject('英语', '英语'),
    _StudySubject('阅读', '阅读 绘本'),
    _StudySubject('科普', '科普 纪录片'),
    _StudySubject('思维', '思维训练 奥数'),
  ];

  // B站搜索对相同 keyword + order + page 返回高度稳定。
  // “全部”页刷新必须换搜索主题；加载更多则保持当前主题继续翻页。
  static const List<_StudyTheme> _allThemes = [
    _StudyTheme('综合学习', '学习 知识 小学 科普 课程'),
    _StudyTheme('科学实验', '少儿 科学实验 科普 自然 探索'),
    _StudyTheme('语文阅读', '小学 语文 阅读 古诗 绘本'),
    _StudyTheme('数学思维', '小学 数学 思维训练 奥数 趣味数学'),
    _StudyTheme('英语启蒙', '少儿 英语 启蒙 自然拼读 英语儿歌'),
    _StudyTheme('历史地理', '少儿 历史故事 地理探索 人文知识'),
    _StudyTheme('纪录片', '儿童 纪录片 自然 宇宙 动物'),
    _StudyTheme('手工美育', '少儿 手工 美术 创意 课堂'),
  ];

  static const List<String> _blockedWords = [
    '游戏',
    '王者',
    '和平精英',
    '原神',
    '蛋仔',
    '搞笑',
    '整活',
    '鬼畜',
    '美女',
    '直播',
    '抽奖',
    '开箱',
    '挑战',
    '吓人',
    '恐怖',
    '恋爱',
    '八卦',
    '解说',
    '手游',
    '氪金',
    '带货',
    '擦边',
  ];

  static const List<String> _studySignals = [
    '学习',
    '教育',
    '课程',
    '知识',
    '科普',
    '科学',
    '探索',
    '实验',
    '纪录片',
    '自然',
    '地理',
    '历史',
    '文化',
    '数学',
    '语文',
    '英语',
    '阅读',
    '绘本',
    '编程',
    '思维',
    '课堂',
    '小学',
    '少儿',
    '儿童',
    '正能量',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _gradeController = TabController(length: _grades.length, vsync: this)
      ..addListener(() {
        if (!_gradeController.indexIsChanging) {
          _scheduleLoad();
        }
      });
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  bool get _isAllSubject => _subjectIndex == 0;

  String get _cacheKey => _isAllSubject
      ? '${_gradeController.index}:$_subjectIndex:$_allThemeIndex:${StudySafetyPrefs.settingsSignature}'
      : '${_gradeController.index}:$_subjectIndex:${StudySafetyPrefs.settingsSignature}';

  List<_StudyTheme> get _customThemes => StudySafetyPrefs.customKeywords
      .map((keyword) => _StudyTheme(keyword, keyword))
      .toList(growable: false);

  List<_StudyTheme> get _activeAllThemes {
    final custom = _customThemes;
    return switch (StudySafetyPrefs.sourceMode) {
      StudyContentSourceMode.builtin => _allThemes,
      StudyContentSourceMode.custom => custom,
      StudyContentSourceMode.mixed => [..._allThemes, ...custom],
    };
  }

  bool get _hasActiveAllSource => _activeAllThemes.isNotEmpty;

  _StudyTheme get _currentAllTheme {
    final active = _activeAllThemes;
    if (active.isEmpty) return const _StudyTheme('未配置内容源', '');
    return active[_allThemeIndex % active.length];
  }

  String get _keyword {
    final grade = _grades[_gradeController.index].keyword;
    final subject = _subjects[_subjectIndex].keyword;
    if (_isAllSubject) {
      final theme = _currentAllTheme.keyword;
      if (grade == '启蒙教育') {
        return '启蒙教育 $theme';
      }
      return '$grade $theme';
    }
    return '$grade $subject 小学 课程 同步教材';
  }

  Future<void> _refresh() async {
    if (_loading || _loadingMore) return;
    if (_isAllSubject) {
      final sourceCount = _activeAllThemes.length;
      setState(() {
        if (sourceCount > 0) {
          _allThemeIndex = (_allThemeIndex + 1) % sourceCount;
        }
        _items = const [];
        _currentPage = 1;
        _hasMore = true;
        _emptyPageCount = 0;
        _autoFillCount = 0;
        _error = null;
      });
    }
    await _load(force: true);
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(_tabDebounce, () => _load());
  }

  bool _useCachedResult({bool force = false}) {
    if (force) return false;
    final cached = _cache[_cacheKey];
    if (cached == null) return false;
    if (DateTime.now().difference(cached.createdAt) > _cacheTtl) return false;
    setState(() {
      _items = cached.items;
      _currentPage = cached.page;
      _hasMore = cached.hasMore;
      _emptyPageCount = cached.emptyPageCount;
      _autoFillCount = 0;
      _error = null;
      _loading = false;
      _loadingMore = false;
    });
    return true;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _load({bool force = false}) async {
    _debounce?.cancel();
    if (_isAllSubject && !_hasActiveAllSource) {
      setState(() {
        _items = const [];
        _currentPage = 1;
        _hasMore = false;
        _emptyPageCount = 0;
        _autoFillCount = 0;
        _error = null;
        _loading = false;
        _loadingMore = false;
      });
      return;
    }
    if (_useCachedResult(force: force)) return;
    await _fetchPage(page: 1, replace: true);
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    await _fetchPage(page: _currentPage + 1, replace: false);
  }

  Future<void> _fetchPage({required int page, required bool replace}) async {
    final int current = ++_requestId;
    setState(() {
      if (replace) {
        _loading = true;
        _error = null;
        _hasMore = true;
        _currentPage = 1;
        _emptyPageCount = 0;
        _autoFillCount = 0;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final res = await SearchHttp.searchByType<SearchVideoData>(
        searchType: SearchType.video,
        keyword: _keyword,
        page: page,
        order: _isAllSubject ? 'pubdate' : 'totalrank',
        onSuccess: (String _) {},
      );
      if (!mounted || current != _requestId) return;
      switch (res) {
        case Success<SearchVideoData>(:final response):
          final rawItems = response.list ?? const <SearchVideoItemModel>[];
          final filtered = _filter(rawItems);
          final merged = replace ? filtered : _mergeItems(_items, filtered);
          final emptyPageCount = filtered.isEmpty ? _emptyPageCount + 1 : 0;
          final hasMore = rawItems.isNotEmpty && emptyPageCount < 2;
          _cache[_cacheKey] = _StudyCacheEntry(
            merged,
            DateTime.now(),
            page,
            hasMore,
            emptyPageCount,
          );
          setState(() {
            _items = merged;
            _currentPage = page;
            _hasMore = hasMore;
            _emptyPageCount = emptyPageCount;
            _loading = false;
            _loadingMore = false;
          });
          _scheduleEnsureScrollableContent();
        case Error(:final errMsg):
          setState(() {
            if (replace) _items = const [];
            _error = errMsg ?? '加载失败';
            _loading = false;
            _loadingMore = false;
            if (!replace) _hasMore = false;
          });
        default:
          setState(() {
            if (replace) _items = const [];
            _error = '加载失败';
            _loading = false;
            _loadingMore = false;
            if (!replace) _hasMore = false;
          });
      }
    } catch (e) {
      if (!mounted || current != _requestId) return;
      setState(() {
        if (replace) _items = const [];
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
        if (!replace) _hasMore = false;
      });
    }
  }

  void _scheduleEnsureScrollableContent() {
    if (_autoFillScheduled) return;
    final scheduledRequestId = _requestId;
    _autoFillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFillScheduled = false;
      if (!mounted || scheduledRequestId != _requestId) return;
      if (!_scrollController.hasClients) return;
      if (_loading || _loadingMore || !_hasMore) return;
      if (_autoFillCount >= _maxAutoFillPages) return;
      final position = _scrollController.position;
      final contentTooShort = position.maxScrollExtent < position.viewportDimension * 0.35;
      final notEnoughItems = _items.length < _minBufferedItems;
      if (contentTooShort || notEnoughItems) {
        _autoFillCount += 1;
        _loadMore();
      }
    });
  }

  List<SearchVideoItemModel> _mergeItems(
    List<SearchVideoItemModel> current,
    List<SearchVideoItemModel> next,
  ) {
    final seen = <String>{
      for (final item in current) item.bvid?.toString() ?? item.aid.toString(),
    };
    return [
      ...current,
      for (final item in next)
        if (seen.add(item.bvid?.toString() ?? item.aid.toString())) item,
    ];
  }

  List<SearchVideoItemModel> _filter(List<SearchVideoItemModel> source) {
    final grade = _grades[_gradeController.index].keyword;
    final blockWords = [..._blockedWords, ...StudySafetyPrefs.extraBlockWords];
    return source.where((item) {
      final text = '${item.title} ${item.desc ?? ''} ${item.owner.name ?? ''} ${item.tag ?? ''}';
      if (StudySafetyPrefs.containsAny(text, blockWords)) return false;
      if (!StudySafetyPrefs.passesWhitelist(text)) return false;
      if (_isAllSubject) return true;
      if (grade != '启蒙教育' && !text.contains(grade)) return false;
      return true;
    }).toList(growable: false);
  }

  String get _emptyMessage {
    if (_isAllSubject && !_hasActiveAllSource) {
      return '当前未配置自定义内容源。请进入家长设置添加关键词，或切换为内置主题。';
    }
    if (StudySafetyPrefs.whitelistWords.isNotEmpty) {
      return '当前白名单较严格，暂时没有匹配课程。请进入家长设置调整白名单或关键词。';
    }
    return _isAllSubject
        ? '当前主题「${_currentAllTheme.label}」暂时没有找到合适课程，下拉换一个主题。'
        : '暂时没有找到合适课程，下拉或点击右上角刷新。';
  }

  Future<void> _openParentSettings() async {
    final changed = await StudyParentSettingsPage.open(context);
    if (!mounted || !changed) return;
    setState(() {
      _cache.clear();
      _allThemeIndex = 0;
      _items = const [];
      _currentPage = 1;
      _hasMore = true;
      _emptyPageCount = 0;
      _autoFillCount = 0;
      _error = null;
    });
    await _load(force: true);
  }

  void _selectSubject(int index) {
    if (_subjectIndex == index) return;
    setState(() => _subjectIndex = index);
    _scheduleLoad();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('PiliStudy 学习'),
        actions: [
          IconButton(
            tooltip: _isAllSubject ? '换一批学习内容' : '刷新学习内容',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '家长设置',
            onPressed: _openParentSettings,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: '家长登录 / 我的',
            onPressed: () => Get.find<MainController>().toMinePage(),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _gradeController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _grades.map((e) => Tab(text: e.label)).toList(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _subjectBar(theme),
            Expanded(child: _body(theme)),
          ],
        ),
      ),
    );
  }

  Widget _subjectBar(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _subjects.length; i++) ...[
              ChoiceChip(
                label: Text(_subjects[i].label),
                selected: _subjectIndex == i,
                onSelected: (_) => _selectSubject(i),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(_isAllSubject ? '换一批内容' : '重新加载'),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.school_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            _emptyMessage,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isLandscape = width > height;
        final columns = _gridColumnCount(width, isLandscape);
        final gridWidth = width - _gridPadding * 2;
        final cardWidth = (gridWidth - (columns - 1) * _gridSpacing) / columns;
        final textScale = MediaQuery.textScalerOf(
          context,
        ).scale(1.0).clamp(1.0, 1.35).toDouble();
        final cardHeight = _cardMainAxisExtent(cardWidth, textScale);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _studyTopicHeader(theme)),
              SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _gridPadding,
                _gridPadding,
                _gridPadding,
                isLandscape ? 16 : 24,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: cardHeight,
                  crossAxisSpacing: _gridSpacing,
                  mainAxisSpacing: _gridSpacing,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) => RepaintBoundary(
                  child: _StudyVideoCard(item: _items[index]),
                ),
              ),
            ),
              SliverToBoxAdapter(child: _loadMoreFooter(theme)),
            ],
          ),
        );
      },
    );
  }

  int _gridColumnCount(double width, bool isLandscape) {
    if (width >= 900) return 4;
    if (width >= 620) return 3;
    return isLandscape && width >= 520 ? 3 : 2;
  }

  double _cardMainAxisExtent(double cardWidth, double textScale) {
    final coverHeight = cardWidth / Style.aspectRatio;
    // Bottom content includes padding, two title lines, stats, author and gaps.
    // v0.4 reserved too much space to avoid overflow; on foldables that became
    // visible dead air. Keep a compact but safe reserve instead.
    final contentHeight = 84 * textScale + 10;
    return coverHeight + contentHeight;
  }

  Widget _studyTopicHeader(ThemeData theme) {
    if (!_isAllSubject) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _hasActiveAllSource
                  ? '当前主题：${_currentAllTheme.label}｜${StudySafetyPrefs.sourceMode.label}｜下拉换一批'
                  : '当前未配置自定义内容源｜请进入家长设置',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadMoreFooter(ThemeData theme) {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            '已经到底了，下拉刷新可换一批内容',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('加载更多'),
        ),
      ),
    );
  }
}

class _StudyVideoCard extends StatelessWidget {
  const _StudyVideoCard({required this.item});

  final SearchVideoItemModel item;

  Future<void> _open() async {
    int? cid = item.cid;
    Dimension? dimension = item.dimension;
    if (cid == null) {
      final res = await SearchHttp.ab2cWithDimension(
        aid: item.aid,
        bvid: item.bvid,
      );
      cid = res?.cid;
      dimension = res?.dimension;
    }
    if (cid == null) {
      SmartDialog.showToast('暂时无法打开这个视频');
      return;
    }
    PageUtils.toVideoPage(
      aid: item.aid,
      bvid: item.bvid,
      cid: cid,
      cover: item.cover,
      title: item.title,
      dimension: dimension,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: _open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: Style.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => NetworkImgLayer(
                      src: item.cover,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    ),
                  ),
                  if (item.duration > 0)
                    PBadge(
                      text: DurationUtils.formatDuration(item.duration),
                      right: 6,
                      bottom: 6,
                      type: .gray,
                    ),
                  const PBadge(
                    text: '学习',
                    left: 6,
                    top: 6,
                    type: .primary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  final showStats = availableHeight >= 50;
                  final showOwner = availableHeight >= 70;
                  final titleLines = availableHeight >= 42 ? 2 : 1;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.25),
                        ),
                        if (showStats) ...[
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                StatWidget(type: .play, value: item.stat.view),
                                if (!StudySafetyPrefs.disableDanmaku) ...[
                                  const SizedBox(width: 8),
                                  StatWidget(type: .danmaku, value: item.stat.danmu),
                                ],
                                const SizedBox(width: 8),
                                Text(
                                  DateFormatUtils.dateFormat(item.pubdate ?? 0),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (showOwner) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.owner.name ?? '未知 UP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyCacheEntry {
  final List<SearchVideoItemModel> items;
  final DateTime createdAt;
  final int page;
  final bool hasMore;
  final int emptyPageCount;

  const _StudyCacheEntry(
    this.items,
    this.createdAt,
    this.page,
    this.hasMore,
    this.emptyPageCount,
  );
}

class _StudyGrade {
  final String label;
  final String keyword;
  const _StudyGrade(this.label, this.keyword);
}

class _StudySubject {
  final String label;
  final String keyword;
  const _StudySubject(this.label, this.keyword);
}

class _StudyTheme {
  final String label;
  final String keyword;
  const _StudyTheme(this.label, this.keyword);
}
