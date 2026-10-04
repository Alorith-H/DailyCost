import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/analysis_page.dart';
import '../../features/calculator/calculator_page.dart';
import '../../features/data_manage/data_manage_page.dart';
import '../../features/data_manage/recycle_bin_page.dart';
import '../../features/decisions/decisions_page.dart';
import '../../features/home/home_page.dart';
import '../../features/item_edit/item_edit_page.dart';
import '../../features/settings/settings_page.dart';

/// 路由表：三分支底部导航 + 壳外全屏表单页。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/calc',
              name: 'calc',
              builder: (context, state) => const CalculatorPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/item/new',
        name: 'itemCreate',
        builder: (context, state) => const ItemEditPage.create(),
      ),
      GoRoute(
        path: '/item/edit/:id',
        name: 'itemEdit',
        builder: (context, state) => ItemEditPage.edit(
          itemId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: '/data-manage',
        name: 'dataManage',
        builder: (context, state) => const DataManagePage(),
        routes: [
          GoRoute(
            path: 'recycle-bin',
            name: 'recycleBin',
            builder: (context, state) => const RecycleBinPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/analysis',
        name: 'analysis',
        builder: (context, state) => const AnalysisPage(),
      ),
      GoRoute(
        path: '/decisions',
        name: 'decisions',
        builder: (context, state) => const DecisionsPage(),
      ),
    ],
  );
});

/// 底部导航外壳（首页 / 试算器 / 设置）。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: '试算器',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
