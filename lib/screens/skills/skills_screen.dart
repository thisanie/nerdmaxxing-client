import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/skills_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SkillsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SkillsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(SkillsProvider provider) {
    if (provider.isLoading && provider.skills.isEmpty) {
      return const _RefreshableState(child: CircularProgressIndicator());
    }
    if (provider.skills.isEmpty) {
      return const _RefreshableState(
        child: EmptyState(
          icon: Icons.workspace_premium_outlined,
          title: 'No skills yet.',
          message: 'Complete your first challenge and start building your collection.',
        ),
      );
    }
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: provider.skills.length,
      itemBuilder: (context, index) {
        final skill = provider.skills[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: AppColors.accent,
                  size: 28,
                ),
                Text(
                  skill.skillName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Verified',
                  style: TextStyle(color: AppColors.success, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RefreshableState extends StatelessWidget {
  final Widget child;

  const _RefreshableState({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(child: child),
        ),
      ],
    );
  }
}
