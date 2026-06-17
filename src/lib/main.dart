import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_bootstrap.dart';
import 'modules/registry.dart';
import 'router/router.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: BulterColors.canvas,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 1) 注册所有模块 + 同步子 Agent / 工具注册表
  await bootstrapApp();

  runApp(
    ProviderScope(
      child: BulterApp(),
    ),
  );
}

class BulterApp extends StatelessWidget {
  BulterApp({super.key});

  final _router = buildRouter(ModuleRegistry.instance);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bulter',
      debugShowCheckedModeBanner: false,
      theme: BulterTheme.light(),
      routerConfig: _router,
    );
  }
}
