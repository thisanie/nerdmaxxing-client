import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../models/discover.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../services/discover_service.dart';
import '../../theme/app_theme.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _imageUrl = TextEditingController();
  final _shortDescription = TextEditingController();
  final _fullDescription = TextEditingController();
  final _resourceTitle = TextEditingController();
  final _resourceUrl = TextEditingController();
  final _resourceRationale = TextEditingController();
  final _effortMin = TextEditingController();
  final _effortMax = TextEditingController();
  final _duration = TextEditingController();

  String _difficulty = 'BEGINNER';
  late final Future<DiscoverFeed> _categoriesFuture;
  String? _selectedCategoryId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title,
      _imageUrl,
      _shortDescription,
      _fullDescription,
      _resourceTitle,
      _resourceUrl,
      _resourceRationale,
      _effortMin,
      _effortMax,
      _duration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _categoriesFuture = context.read<DiscoverService>().getFeed();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final effortMin = int.tryParse(_effortMin.text.trim());
    final effortMax = int.tryParse(_effortMax.text.trim());
    final duration = int.tryParse(_duration.text.trim());
    if (_selectedCategoryId == null ||
        effortMin == null ||
        effortMax == null ||
        duration == null ||
        effortMin < 1 ||
        effortMax < effortMin ||
        duration < 1) {
      setState(() => _error = 'Choose a category and enter valid timing values.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final resource = ChallengeResource(
        id: '',
        title: _resourceTitle.text.trim(),
        url: _resourceUrl.text.trim(),
        resourceType: 'LINK',
        rationale: _resourceRationale.text.trim(),
        orderIndex: 0,
      );
      await context.read<ChallengesService>().create(
            title: _title.text.trim(),
            imageUrl: _imageUrl.text.trim(),
            resources: [resource],
            shortDescription: _shortDescription.text.trim(),
            fullDescription: _fullDescription.text.trim(),
            difficultyLevel: _difficulty,
            categoryIds: [_selectedCategoryId!],
            estimatedEffortMinMinutes: effortMin,
            estimatedEffortMaxMinutes: effortMax,
            estimatedDurationMinutes: duration,
            verificationType: 'SELF_REPORTED',
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Challenge created as a private draft.')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a Challenge')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Design a small adventure for someone curious.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrl,
              decoration: const InputDecoration(labelText: 'Image URL'),
              validator: (v) => (v == null || !v.trim().startsWith('http'))
                  ? 'A valid http(s) URL is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortDescription,
              decoration: const InputDecoration(labelText: 'Short description'),
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullDescription,
              decoration: const InputDecoration(labelText: 'What will they do?'),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            FutureBuilder<DiscoverFeed>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final categories = snapshot.data?.categories ?? const [];
                if (categories.isEmpty) {
                  return const Text('No categories are available right now.');
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategoryId = value),
                  validator: (value) => value == null ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: const [
                DropdownMenuItem(value: 'BEGINNER', child: Text('Beginner')),
                DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediate')),
                DropdownMenuItem(value: 'ADVANCED', child: Text('Advanced')),
              ],
              onChanged: (v) => setState(() => _difficulty = v ?? 'BEGINNER'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _effortMin,
              decoration: const InputDecoration(labelText: 'Minimum effort (minutes)'),
              keyboardType: TextInputType.number,
              validator: _positiveIntegerValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _effortMax,
              decoration: const InputDecoration(labelText: 'Maximum effort (minutes)'),
              keyboardType: TextInputType.number,
              validator: _positiveIntegerValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _duration,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
              validator: _positiveIntegerValidator,
            ),
            const SizedBox(height: 24),
            Text('One resource to get started', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _resourceTitle,
              decoration: const InputDecoration(labelText: 'Resource title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _resourceUrl,
              decoration: const InputDecoration(labelText: 'Resource URL'),
              validator: (v) => (v == null || !v.trim().startsWith('http'))
                  ? 'A valid http(s) URL is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _resourceRationale,
              decoration: const InputDecoration(labelText: 'Why is this resource useful?'),
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Creating...' : 'Create Challenge'),
            ),
          ],
        ),
      ),
    );
  }

  String? _positiveIntegerValidator(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    return minutes == null || minutes < 1 ? 'Enter a positive number' : null;
  }
}
