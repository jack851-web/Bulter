import 'package:flutter/material.dart';

import '../bulter_module.dart';
import '../../theme/tokens.dart';
import 'butler_home_page.dart';

/// Butler 中枢模块
class ButlerModule implements BulterModule {
  const ButlerModule();

  @override
  String get id => ModuleId.butler;

  @override
  String get displayName => 'Butler';

  @override
  Color get brandColor => BulterColors.butler;

  @override
  String get iconName => 'sparkles';

  @override
  String get entryRoute => '/butler';

  @override
  Widget buildHomePage(BuildContext context) => const ButlerHomePage();

  @override
  List<ModuleTab> get tabs => const [];

  @override
  SpecialistAgent? get subAgent => null;

  @override
  List<ToolDefinition> get tools => const [];

  @override
  BriefingGenerator? get briefingGenerator => null;

  @override
  Future<void> onRegister() async {}

  @override
  Future<void> onDispose() async {}
}
