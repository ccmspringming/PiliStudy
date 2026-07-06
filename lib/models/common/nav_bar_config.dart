import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/pages/study/view.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:flutter/material.dart';

enum NavigationBarType implements EnumWithLabel {
  home(
    '学习',
    Icon(Icons.school_outlined),
    Icon(Icons.school),
    StudyPage(),
  ),
  mine(
    '我的',
    Icon(Icons.person_outline),
    Icon(Icons.person),
    MinePage(),
  ),
  ;

  @override
  final String label;
  final Icon icon;
  final Icon selectIcon;
  final Widget page;

  const NavigationBarType(this.label, this.icon, this.selectIcon, this.page);
}
