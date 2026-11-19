import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../discover/discover_screen.dart';
import '../discover/people_discover_screen.dart';
import '../daily_quest/daily_quest_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/group_chat_screen.dart';
import '../skills/skills_screen.dart';
import '../evidence/admin_hub_screen.dart';
import '../../providers/notification_badge_provider.dart';
import '../notifications/notifications_screen.dart';
import '../../services/api_client.dart';
import '../../services/groups_service.dart';
import '../../services/daily_quests_service.dart';
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
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => _screens[index]),
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
          builder: (_) => const AdminHubScreen(),
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
    final dailyQuestAttemptId = data['daily_quest_attempt_id'];
    final dailyQuestId = data['daily_quest_id'];
    final deepLink = data['deep_link']?.toLowerCase() ?? '';
    if ((dailyQuestAttemptId?.isNotEmpty ?? false) ||
        (dailyQuestId?.isNotEmpty ?? false) ||
        deepLink.contains('daily-quest')) {
      try {
        final dailyQuests = context.read<DailyQuestsService>();
        if (dailyQuestAttemptId != null && dailyQuestAttemptId.isNotEmpty) {
          final result = await dailyQuests.getAttemptResult(dailyQuestAttemptId);
          if (!mounted) return;
          _navigatorKeys[0].currentState?.push(
            MaterialPageRoute(
              builder: (_) => DailyQuestRewardScreen(result: result),
            ),
          );
          return;
        }
        final today = await dailyQuests.getToday();
        final localDate = data['daily_quest_local_date'];
        if (!mounted) return;
        if ((dailyQuestId == null || dailyQuestId == today.quest?.id) &&
            (localDate == null || localDate == today.localDate)) {
          _navigatorKeys[0].currentState?.push(
            MaterialPageRoute(builder: (_) => DailyQuestScreen(today: today)),
          );
          return;
        }
      } on ApiException {
        // Fall through to the notifications list if the quest result is unavailable.
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
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: _navigationIndex,
                  children: _tabNavigators,
                ),
              ),
            ),
            _BottomNavigationBar(
              currentIndex: _navigationIndex,
              onTap: _onNavigationTap,
              isAdmin: _isAdmin,
            ),
          ],
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
    (Icons.home_outlined, 'Home'),
    (Icons.explore_outlined, 'Discover'),
    (Icons.emoji_events_outlined, 'Rank'),
    (Icons.account_circle_outlined, 'Profile'),
  ];

  static const _pillHeight = 64.0;
  static const _containerHeight = 76.0;
  static const _horizontalMargin = 14.0;
  static const _bottomPadding = 12.0;
  static const _pillInset = 8.0;
  static const _itemSize = 48.0;
  static const _itemGap = 4.0;
  static const _selectedItemInset = 14.0;
  static const _idleItemInset = 12.0;
  static const _itemRadius = 22.0;
  static const _pillRadius = 30.0;
  static const _iconSize = 24.0;
  static const _labelGap = 4.0;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final brightness = Theme.of(context).brightness;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final items = [
      ..._items,
      if (isAdmin)
        (Icons.fact_check_outlined, 'Admin'),
    ];
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _containerHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _horizontalMargin,
            0,
            _horizontalMargin,
            _bottomPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(),
              child: Container(
                width: double.infinity,
                height: _pillHeight,
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark
                      ? HomePalette.darkSurfaceAlt
                      : HomePalette.lightSurface,
                  border: Border.all(color: HomePalette.border(brightness)),
                  borderRadius: BorderRadius.circular(_pillRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: brightness == Brightness.dark ? .24 : .08,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _pillInset,
                    vertical: _pillInset,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        if (index > 0) const SizedBox(width: _itemGap),
                        _NavigationItem(
                          icon: items[index].$1,
                          label: items[index].$2,
                          selected: currentIndex == index,
                          reduceMotion: reduceMotion,
                          onTap: () => onTap(index),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
  final bool reduceMotion;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final selectedBackground = HomePalette.primary;
    final selectedForeground = HomePalette.ink;
    final color = selected
        ? selectedForeground
        : HomePalette.textSecondary(brightness);
    final animationDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 450);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_BottomNavigationBar._itemRadius),
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutBack,
            constraints: const BoxConstraints(
              minWidth: _BottomNavigationBar._itemSize,
              minHeight: _BottomNavigationBar._itemSize,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: selected
                  ? _BottomNavigationBar._selectedItemInset
                  : _BottomNavigationBar._idleItemInset,
            ),
            decoration: BoxDecoration(
              color: selected ? selectedBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(
                _BottomNavigationBar._itemRadius,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey('icon-$selected'),
                  tween: Tween(begin: selected ? 0.7 : 1, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: Icon(
                    icon,
                    size: _BottomNavigationBar._iconSize,
                    color: color,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: selected ? 1 : 0),
                  duration: animationDuration,
                  curve: Curves.easeOutBack,
                  builder: (context, reveal, child) => ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: reveal.clamp(0, 1),
                      child: Opacity(opacity: reveal.clamp(0, 1), child: child),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: _BottomNavigationBar._labelGap,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: AppFonts.home(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
