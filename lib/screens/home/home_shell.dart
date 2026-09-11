import 'package:flutter/material.dart';

import '../discover/discover_screen.dart';
import '../discover/people_discover_screen.dart';
import '../challenge/create_challenge_screen.dart';
import '../profile/profile_screen.dart';
import '../skills/skills_screen.dart';
import '../../theme/app_theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final List<bool> _tabAtRoot = [
    for (var i = 0; i < _screens.length; i++) true,
  ];

  static const _screens = [
    HomeScreen(),
    PeopleDiscoverScreen(),
    SkillsScreen(),
    ProfileScreen(),
  ];

  late final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    for (var i = 0; i < _screens.length; i++) GlobalKey<NavigatorState>(),
  ];

  late final List<Widget> _tabNavigators = [
    for (var i = 0; i < _screens.length; i++)
      Navigator(
        key: _navigatorKeys[i],
        observers: [
          _TabNavigatorObserver(
            onRouteDepthChanged: (isRoot) {
              if (mounted && _tabAtRoot[i] != isRoot) {
                setState(() => _tabAtRoot[i] = isRoot);
              }
            },
          ),
        ],
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _screens[i]),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _index == 0 &&
          !(_navigatorKeys[_index].currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navigator = _navigatorKeys[_index].currentState;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(index: _index, children: _tabNavigators),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _navigationIndex,
          selectedItemColor: _tabAtRoot[_index] ? null : AppColors.textPrimary,
          onTap: _onNavigationTap,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              label: 'Discover',
            ),
            BottomNavigationBarItem(icon: _AddNavigationIcon(), label: ''),
            BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_outlined),
              label: 'Skills',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  int get _navigationIndex => _index >= 2 ? _index + 1 : _index;

  void _onNavigationTap(int navigationIndex) {
    if (navigationIndex == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CreateChallengeScreen()));
      return;
    }
    final tabIndex = navigationIndex > 2
        ? navigationIndex - 1
        : navigationIndex;
    if (tabIndex == 3) {
      _navigatorKeys[tabIndex].currentState?.popUntil((route) => route.isFirst);
    }
    setState(() => _index = tabIndex);
  }
}

class _AddNavigationIcon extends StatelessWidget {
  const _AddNavigationIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
    );
  }
}

class _TabNavigatorObserver extends NavigatorObserver {
  final ValueChanged<bool> onRouteDepthChanged;
  int _depth = 0;

  _TabNavigatorObserver({required this.onRouteDepthChanged});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _depth++;
    onRouteDepthChanged(_depth <= 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _depth = (_depth - 1).clamp(0, 999999);
    onRouteDepthChanged(_depth <= 1);
  }
}
