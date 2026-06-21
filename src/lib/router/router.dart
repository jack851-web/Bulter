import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/memory/memory_page.dart';
import '../features/settings/model_config_page.dart';
import '../features/settings/user_profile_page.dart';
import '../modules/bulter_module.dart';
import '../modules/registry.dart';
import 'app_shell.dart';

/// 构建 Bulter 路由表。
///
/// Step 1 阶段：使用 `StatefulShellRoute.indexedStack` 索引化各模块主页，
/// `_ShellHost` 读取 `navigationShell.currentIndex` 并把 `goBranch` 回调
/// 传给 `AppShell`，**模块切换的单一数据源 = 路由的 `currentIndex`**。
GoRouter buildRouter(ModuleRegistry registry) {
  final modules = registry.capsuleModules;
  return GoRouter(
    initialLocation: '/butler',
    routes: [
      // 设置类子页（覆盖在 Shell 之上；Step 4 接入）
      GoRoute(
        path: '/settings/model',
        name: 'settings.model',
        builder: (context, state) => const ModelConfigPage(),
      ),
      // 记忆浏览页（Step 6：长期记忆管理）
      GoRoute(
        path: '/memory',
        name: 'memory',
        builder: (context, state) => const MemoryPage(),
      ),
      // 用户画像页（Step 7：查看 / 编辑 AI 抽取的画像）
      GoRoute(
        path: '/settings/profile',
        name: 'settings.profile',
        builder: (context, state) => const UserProfilePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ShellHost(navigationShell: navigationShell, modules: modules);
        },
        branches: [
          for (final m in modules)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: m.entryRoute,
                  name: m.id,
                  builder: (context, state) => const _BranchPlaceholder(),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// 把 `StatefulNavigationShell.currentIndex` 与 `goBranch` 桥接到 `AppShell`。
class _ShellHost extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<BulterModule> modules;

  const _ShellHost({required this.navigationShell, required this.modules});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      modules: modules,
      activeIndex: navigationShell.currentIndex,
      onIndexChange: (i) {
        if (i == navigationShell.currentIndex) return;
        // 切换模块时把目标分支的栈重置到 entryRoute，避免返回手势回到老模块的 stack。
        navigationShell.goBranch(i, initialLocation: true);
      },
    );
  }
}

/// 实际内容由 `AppShell` 渲染；`StatefulShellBranch` 需要一个占位 builder。
class _BranchPlaceholder extends StatelessWidget {
  const _BranchPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
