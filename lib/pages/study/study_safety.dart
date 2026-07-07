import 'dart:convert';
import 'dart:math';

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:crypto/crypto.dart';

enum StudyContentSourceMode { builtin, custom, mixed }

abstract final class StudySafetyPrefs {
  static const String _saltChars = '0123456789abcdef';

  static StudyContentSourceMode get sourceMode {
    final index = GStorage.setting.get(
      SettingBoxKey.studyContentSourceMode,
      defaultValue: StudyContentSourceMode.builtin.index,
    );
    if (index is int &&
        index >= 0 &&
        index < StudyContentSourceMode.values.length) {
      return StudyContentSourceMode.values[index];
    }
    return StudyContentSourceMode.builtin;
  }

  static set sourceMode(StudyContentSourceMode mode) {
    GStorage.setting.put(SettingBoxKey.studyContentSourceMode, mode.index);
  }

  static String get customKeywordsRaw => GStorage.setting.get(
    SettingBoxKey.studyCustomKeywords,
    defaultValue: '',
  );
  static set customKeywordsRaw(String value) {
    GStorage.setting.put(SettingBoxKey.studyCustomKeywords, value);
  }

  static String get whitelistWordsRaw => GStorage.setting.get(
    SettingBoxKey.studyWhitelistWords,
    defaultValue: '',
  );
  static set whitelistWordsRaw(String value) {
    GStorage.setting.put(SettingBoxKey.studyWhitelistWords, value);
  }

  static String get extraBlockWordsRaw => GStorage.setting.get(
    SettingBoxKey.studyExtraBlockWords,
    defaultValue: '',
  );
  static set extraBlockWordsRaw(String value) {
    GStorage.setting.put(SettingBoxKey.studyExtraBlockWords, value);
  }

  static bool get hideComments => GStorage.setting.get(
    SettingBoxKey.studyHideComments,
    defaultValue: true,
  );
  static set hideComments(bool value) {
    GStorage.setting.put(SettingBoxKey.studyHideComments, value);
  }

  static bool get disableDanmaku => GStorage.setting.get(
    SettingBoxKey.studyDisableDanmaku,
    defaultValue: true,
  );
  static set disableDanmaku(bool value) {
    GStorage.setting.put(SettingBoxKey.studyDisableDanmaku, value);
  }

  static bool get largeScreenMode => GStorage.setting.get(
    SettingBoxKey.studyLargeScreenMode,
    defaultValue: false,
  );
  static set largeScreenMode(bool value) {
    GStorage.setting.put(SettingBoxKey.studyLargeScreenMode, value);
  }

  static List<String> get customKeywords => parseWords(customKeywordsRaw);
  static List<String> get whitelistWords => parseWords(whitelistWordsRaw);
  static List<String> get extraBlockWords => parseWords(extraBlockWordsRaw);

  static Future<void> saveSettings({
    required StudyContentSourceMode sourceMode,
    required String customKeywordsRaw,
    required String whitelistWordsRaw,
    required String extraBlockWordsRaw,
    required bool hideComments,
    required bool disableDanmaku,
    required bool largeScreenMode,
  }) async {
    await Future.wait([
      GStorage.setting.put(SettingBoxKey.studyContentSourceMode, sourceMode.index),
      GStorage.setting.put(SettingBoxKey.studyCustomKeywords, customKeywordsRaw),
      GStorage.setting.put(SettingBoxKey.studyWhitelistWords, whitelistWordsRaw),
      GStorage.setting.put(SettingBoxKey.studyExtraBlockWords, extraBlockWordsRaw),
      GStorage.setting.put(SettingBoxKey.studyHideComments, hideComments),
      GStorage.setting.put(SettingBoxKey.studyDisableDanmaku, disableDanmaku),
      GStorage.setting.put(SettingBoxKey.studyLargeScreenMode, largeScreenMode),
    ]);
  }

  static bool get hasParentPin {
    final hash = GStorage.setting.get(SettingBoxKey.studyParentPinHash);
    final salt = GStorage.setting.get(SettingBoxKey.studyParentPinSalt);
    return hash is String && hash.isNotEmpty && salt is String && salt.isNotEmpty;
  }

  static Future<void> setParentPin(String pin) async {
    final salt = _generateSalt();
    await GStorage.setting.put(SettingBoxKey.studyParentPinSalt, salt);
    await GStorage.setting.put(
      SettingBoxKey.studyParentPinHash,
      _hashPin(pin, salt),
    );
  }

  static bool verifyParentPin(String pin) {
    final salt = GStorage.setting.get(SettingBoxKey.studyParentPinSalt);
    final hash = GStorage.setting.get(SettingBoxKey.studyParentPinHash);
    if (salt is! String || hash is! String || salt.isEmpty || hash.isEmpty) {
      return false;
    }
    return _hashPin(pin, salt) == hash;
  }

  static List<String> parseWords(String raw) {
    final seen = <String>{};
    return raw
        .split(RegExp(r'[\n,，;；]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where(seen.add)
        .toList(growable: false);
  }

  static bool containsAny(String text, Iterable<String> words) {
    if (text.isEmpty) return false;
    final normalizedText = text.toLowerCase();
    return words.any((word) {
      final normalizedWord = word.trim().toLowerCase();
      return normalizedWord.isNotEmpty && normalizedText.contains(normalizedWord);
    });
  }

  static bool passesWhitelist(String text) {
    final whitelist = whitelistWords;
    return whitelist.isEmpty || containsAny(text, whitelist);
  }

  static String get settingsSignature {
    final payload = jsonEncode({
      'mode': sourceMode.index,
      'custom': customKeywords,
      'whitelist': whitelistWords,
      'block': extraBlockWords,
    });
    return sha1.convert(utf8.encode(payload)).toString().substring(0, 12);
  }

  static String _generateSalt() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => _saltChars[random.nextInt(_saltChars.length)],
    ).join();
  }

  static String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}

extension StudyContentSourceModeLabel on StudyContentSourceMode {
  String get label => switch (this) {
    StudyContentSourceMode.builtin => '内置主题',
    StudyContentSourceMode.custom => '自定义关键词',
    StudyContentSourceMode.mixed => '内置 + 自定义',
  };
}
