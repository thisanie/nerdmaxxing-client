import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../discover/discover_screen.dart';
import '../discover/people_discover_screen.dart';
import '../profile/profile_screen.dart';
import '../skills/skills_screen.dart';
import '../../theme/app_theme.dart';
import '../../providers/notification_badge_provider.dart';
import '../notifications/notifications_screen.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigation = context.read<NotificationNavigationController>();
      navigation.addListener(_handleNotificationRequest);
      _handleNotificationRequest();
    });
  }

  @override
  void dispose() {
    context
        .read<NotificationNavigationController>()
        .removeListener(_handleNotificationRequest);
    super.dispose();
  }

  void _handleNotificationRequest() {
    final navigation = context.read<NotificationNavigationController>();
    if (!navigation.openNotificationsRequested || !mounted) return;
    navigation.consumeNotificationsRequest();
    _index = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKeys[0].currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    });
    setState(() {});
  }

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
        bottomNavigationBar: _BottomNavigationBar(
          currentIndex: _navigationIndex,
          onTap: _onNavigationTap,
        ),
      ),
    );
  }

  int get _navigationIndex => _index;

  void _onNavigationTap(int navigationIndex) {
    _resetTabStacks();
    setState(() => _index = navigationIndex);
  }

  void _resetTabStacks() {
    for (final key in _navigatorKeys) {
      key.currentState?.popUntil((route) => route.isFirst);
    }
  }
}

class _BottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (Icons.home_outlined, 'Home'),
    (Icons.explore_outlined, 'Discover'),
    (Icons.workspace_premium_outlined, 'Skills'),
    (Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: _NavigationItem(
                      icon: _items[index].$1,
                      label: _items[index].$2,
                      selected: currentIndex == index,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
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
