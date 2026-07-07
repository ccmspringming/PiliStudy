import 'package:PiliPlus/pages/study/study_safety.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class StudyParentSettingsPage extends StatefulWidget {
  const StudyParentSettingsPage({super.key});

  static Future<bool> open(BuildContext context) async {
    if (!StudySafetyPrefs.hasParentPin) {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ParentPinDialog(createMode: true),
      );
      if (created != true) return false;
    } else {
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ParentPinDialog(createMode: false),
      );
      if (verified != true) return false;
    }
    final changed = await Get.to<bool>(() => const StudyParentSettingsPage());
    return changed == true;
  }

  @override
  State<StudyParentSettingsPage> createState() => _StudyParentSettingsPageState();
}

class _StudyParentSettingsPageState extends State<StudyParentSettingsPage> {
  late StudyContentSourceMode _sourceMode;
  late bool _hideComments;
  late bool _disableDanmaku;
  late bool _largeScreenMode;
  late final TextEditingController _customKeywordsController;
  late final TextEditingController _whitelistController;
  late final TextEditingController _extraBlockController;

  @override
  void initState() {
    super.initState();
    _sourceMode = StudySafetyPrefs.sourceMode;
    _hideComments = StudySafetyPrefs.hideComments;
    _disableDanmaku = StudySafetyPrefs.disableDanmaku;
    _largeScreenMode = StudySafetyPrefs.largeScreenMode;
    _customKeywordsController = TextEditingController(
      text: StudySafetyPrefs.customKeywordsRaw,
    );
    _whitelistController = TextEditingController(
      text: StudySafetyPrefs.whitelistWordsRaw,
    );
    _extraBlockController = TextEditingController(
      text: StudySafetyPrefs.extraBlockWordsRaw,
    );
  }

  @override
  void dispose() {
    _customKeywordsController.dispose();
    _whitelistController.dispose();
    _extraBlockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await StudySafetyPrefs.saveSettings(
      sourceMode: _sourceMode,
      customKeywordsRaw: _customKeywordsController.text,
      whitelistWordsRaw: _whitelistController.text,
      extraBlockWordsRaw: _extraBlockController.text,
      hideComments: _hideComments,
      disableDanmaku: _disableDanmaku,
      largeScreenMode: _largeScreenMode,
    );
    SmartDialog.showToast('家长设置已保存');
    Navigator.of(context).pop(true);
  }

  Future<void> _changePin() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ParentPinDialog(
        createMode: true,
        title: '修改家长 PIN',
      ),
    );
    if (changed == true) SmartDialog.showToast('家长 PIN 已修改');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('家长设置'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text('内容源控制', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<StudyContentSourceMode>(
                  value: _sourceMode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '学习内容源',
                  ),
                  items: StudyContentSourceMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _sourceMode = value);
                  },
                ),
                const SizedBox(height: 12),
                _MultiLineSettingField(
                  controller: _customKeywordsController,
                  label: '自定义关键词（一行一个）',
                  hint: '例如：小学数学动画\n自然拼读\n儿童纪录片',
                ),
                const SizedBox(height: 16),
                Text('课程白名单', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _MultiLineSettingField(
                  controller: _whitelistController,
                  label: '白名单关键词（留空则不额外限制）',
                  hint: '例如：语文\n数学\n科普\n纪录片\n实验',
                ),
                const SizedBox(height: 12),
                _MultiLineSettingField(
                  controller: _extraBlockController,
                  label: '额外屏蔽词（一行一个）',
                  hint: '例如：玩具\n盲盒\n短剧',
                ),
                const SizedBox(height: 16),
                Text('观看安全', style: theme.textTheme.titleMedium),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hideComments,
                  title: const Text('隐藏评论区'),
                  subtitle: const Text('默认隐藏视频详情页评论，减少干扰'),
                  onChanged: (value) => setState(() => _hideComments = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _disableDanmaku,
                  title: const Text('关闭弹幕和弹幕互动'),
                  subtitle: const Text('保留视频播放和相关推荐'),
                  onChanged: (value) => setState(() => _disableDanmaku = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _largeScreenMode,
                  title: const Text('大屏/遥控器基础优化'),
                  subtitle: const Text('为平板和安卓电视保留更大的点击目标'),
                  onChanged: (value) => setState(() => _largeScreenMode = value),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _changePin,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: const Text('修改家长 PIN'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('保存并返回学习页'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiLineSettingField extends StatelessWidget {
  const _MultiLineSettingField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        alignLabelWithHint: true,
        hintText: hint,
      ),
    );
  }
}

class _ParentPinDialog extends StatefulWidget {
  const _ParentPinDialog({required this.createMode, this.title});

  final bool createMode;
  final String? title;

  @override
  State<_ParentPinDialog> createState() => _ParentPinDialogState();
}

class _ParentPinDialogState extends State<_ParentPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = '请输入 4-6 位数字 PIN');
      return;
    }
    if (widget.createMode) {
      if (_confirmController.text.trim() != pin) {
        setState(() => _error = '两次输入的 PIN 不一致');
        return;
      }
      await StudySafetyPrefs.setParentPin(pin);
      Navigator.of(context).pop(true);
      return;
    }
    if (!StudySafetyPrefs.verifyParentPin(pin)) {
      setState(() => _error = 'PIN 不正确');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title ?? (widget.createMode ? '设置家长 PIN' : '输入家长 PIN'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '4-6 位数字 PIN'),
            onSubmitted: (_) {
              if (!widget.createMode) _submit();
            },
          ),
          if (widget.createMode)
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '再次输入 PIN'),
              onSubmitted: (_) => _submit(),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.createMode ? '保存' : '进入'),
        ),
      ],
    );
  }
}
