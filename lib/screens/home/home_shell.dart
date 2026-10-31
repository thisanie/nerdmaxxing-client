import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../discover/discover_screen.dart';
import '../discover/people_discover_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/group_chat_screen.dart';
import '../skills/skills_screen.dart';
import '../evidence/admin_evidence_screen.dart';
import '../../providers/notification_badge_provider.dart';
import '../notifications/notifications_screen.dart';
import '../../services/api_client.dart';
import '../../services/groups_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _isAdmin = false;
  late final List<bool> _tabAtRoot;
  late final List<Widget> _screens;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;
  late final List<Widget> _tabNavigators;

  static const _baseScreens = [
    HomeScreen(),
    PeopleDiscoverScreen(),
    SkillsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [..._baseScreens, const SizedBox.shrink()];
    _tabAtRoot = List.filled(_screens.length, true);
    _navigatorKeys = [
      for (var i = 0; i < _screens.length; i++) GlobalKey<NavigatorState>(),
    ];
    _tabNavigators = [
      for (var i = 0; i < _screens.length; i++) _createTabNavigator(i),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigation = context.read<NotificationNavigationController>();
      navigation.addListener(_handleNotificationRequest);
      _handleNotificationRequest();
      _loadAdminAccess();
    });
  }

  Widget _createTabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [
        _TabNavigatorObserver(
          onRouteDepthChanged: (isRoot) {
            if (mounted && _tabAtRoot[index] != isRoot) {
              setState(() => _tabAtRoot[index] = isRoot);
            }
          },
        ),
      ],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _screens[index]),
    );
  }

  Future<void> _loadAdminAccess() async {
    try {
      final profile = await context.read<ProfileService>().getMyProfile();
      if (!mounted || !profile.isAdmin) return;
      final adminNavigator = _navigatorKeys.last.currentState;
      if (adminNavigator == null) return;
      adminNavigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const AdminEvidenceScreen(),
        ),
      );
      setState(() {
        _isAdmin = true;
      });
    } on ApiException {
      // Keep the admin destination hidden if the current profile is unavailable.
    }
  }

  @override
  void dispose() {
    context.read<NotificationNavigationController>().removeListener(
      _handleNotificationRequest,
    );
    super.dispose();
  }

  void _handleNotificationRequest() {
    final navigation = context.read<NotificationNavigationController>();
    if (!navigation.openNotificationsRequested || !mounted) return;
    final data = navigation.pendingData;
    navigation.consumeNotificationsRequest();
    _index = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openNotificationRoute(data);
    });
    setState(() {});
  }

  Future<void> _openNotificationRoute(Map<String, String> data) async {
    final groupId =
        data['group_id'] ??
        data['groupId'] ??
        data['related_id'] ??
        data['entity_id'];
    if (groupId != null && groupId.isNotEmpty) {
      try {
        final group = await context.read<GroupsService>().get(groupId);
        if (!mounted) return;
        _navigatorKeys[0].currentState?.push(
          MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
        );
        return;
      } on ApiException catch (_) {
        // Fall back to the notifications list when the group is unavailable.
      }
    }
    if (!mounted) return;
    _navigatorKeys[0].currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
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
            child: IndexedStack(index: _navigationIndex, children: _tabNavigators),
        ),
        bottomNavigationBar: _BottomNavigationBar(
          currentIndex: _navigationIndex,
          onTap: _onNavigationTap,
          isAdmin: _isAdmin,
        ),
      ),
    );
  }

  int get _navigationIndex => _index.clamp(0, _tabNavigators.length - 1);

  void _onNavigationTap(int navigationIndex) {
    if (navigationIndex < 0 ||
        navigationIndex >= _tabNavigators.length ||
        (navigationIndex == _tabNavigators.length - 1 && !_isAdmin)) {
      return;
    }
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
  final bool isAdmin;

  const _BottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    required this.isAdmin,
  });

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.explore_rounded, 'Discover'),
    (Icons.leaderboard_rounded, 'Rank'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = [
      ..._items,
      if (isAdmin) (Icons.fact_check_rounded, 'Admin'),
    ];
    return Material(
      color: colorScheme.surface,
      shape: Border(top: BorderSide(color: colorScheme.outline)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: _NavigationItem(
                      icon: items[index].$1,
                      label: items[index].$2,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.primaryMuted
                        : AppColors.limeWash)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 2),
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
