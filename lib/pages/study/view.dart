import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
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
  int _subjectIndex = 0;
  int _requestId = 0;
  bool _loading = false;
  String? _error;
  List<SearchVideoItemModel> _items = const [];

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
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _gradeController = TabController(length: _grades.length, vsync: this)
      ..addListener(() {
        if (!_gradeController.indexIsChanging) {
          _load();
        }
      });
    _load();
  }

  @override
  void dispose() {
    _gradeController.dispose();
    super.dispose();
  }

  String get _keyword {
    final grade = _grades[_gradeController.index].keyword;
    final subject = _subjects[_subjectIndex].keyword;
    if (subject.isEmpty) {
      return '$grade 小学 课程 同步教材';
    }
    return '$grade $subject 小学 课程 同步教材';
  }

  Future<void> _load() async {
    final int current = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await SearchHttp.searchByType<SearchVideoData>(
        searchType: SearchType.video,
        keyword: _keyword,
        page: 1,
        order: 'totalrank',
        onSuccess: (String _) {},
      );
      if (!mounted || current != _requestId) return;
      switch (res) {
        case Success<SearchVideoData>(:final response):
          setState(() {
            _items = _filter(response.list ?? const []);
            _loading = false;
          });
        case Error(:final errMsg):
          setState(() {
            _items = const [];
            _error = errMsg ?? '加载失败';
            _loading = false;
          });
        default:
          setState(() {
            _items = const [];
            _error = '加载失败';
            _loading = false;
          });
      }
    } catch (e) {
      if (!mounted || current != _requestId) return;
      setState(() {
        _items = const [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<SearchVideoItemModel> _filter(List<SearchVideoItemModel> source) {
    final grade = _grades[_gradeController.index].keyword;
    return source.where((item) {
      final text = '${item.title} ${item.desc ?? ''} ${item.owner.name ?? ''}';
      if (_blockedWords.any(text.contains)) return false;
      if (grade != '启蒙教育' && !text.contains(grade)) return false;
      return true;
    }).take(30).toList();
  }

  void _selectSubject(int index) {
    if (_subjectIndex == index) return;
    setState(() => _subjectIndex = index);
    _load();
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
            tooltip: '刷新学习内容',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
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
      body: Column(
        children: [
          _subjectBar(theme),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(theme),
            ),
          ),
        ],
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
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载'),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          Icon(Icons.school_outlined, size: 48),
          SizedBox(height: 12),
          Text('暂时没有找到合适课程，下拉或点击右上角刷新。', textAlign: TextAlign.center),
        ],
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 245,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) => _StudyVideoCard(item: _items[index]),
          ),
        ),
      ],
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.35),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        StatWidget(type: .play, value: item.stat.view),
                        const SizedBox(width: 8),
                        StatWidget(type: .danmaku, value: item.stat.danmu),
                        const Spacer(),
                        Text(
                          DateFormatUtils.dateFormat(item.pubdate ?? 0),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
