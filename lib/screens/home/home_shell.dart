import 'package:flutter/material.dart';

import '../discover/discover_screen.dart';
import '../my_challenges/my_challenges_screen.dart';
import '../skills/skills_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    DiscoverScreen(),
    MyChallengesScreen(),
    SkillsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: _screens)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), label: 'My Challenges'),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium_outlined), label: 'Skills'),
        ],
      ),
    );
  }
}
