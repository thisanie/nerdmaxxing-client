import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/challenge.dart';
import '../../services/api_client.dart';
import '../../services/challenges_service.dart';
import '../../theme/app_theme.dart';

class _ResourceDraft {
  final title = TextEditingController();
  final url = TextEditingController();
  final rationale = TextEditingController();

  void dispose() {
    title.dispose();
    url.dispose();
    rationale.dispose();
  }
}

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _shortDescription = TextEditingController();
  final _fullDescription = TextEditingController();
  final _effortMin = TextEditingController();
  final _effortMax = TextEditingController();
  final _resources = <_ResourceDraft>[_ResourceDraft()];

  String _difficulty = 'BEGINNER';
  final _imagePicker = ImagePicker();
  XFile? _image;
  Uint8List? _imageBytes;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title,
      _shortDescription,
      _fullDescription,
      _effortMin,
      _effortMax,
    ]) {
      c.dispose();
    }
    for (final resource in _resources) {
      resource.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null || _imageBytes == null) {
      setState(() => _error = 'Choose a challenge image.');
      return;
    }
    final effortMin = int.tryParse(_effortMin.text.trim());
    final effortMax = int.tryParse(_effortMax.text.trim());
    if (effortMin == null ||
        effortMax == null ||
        effortMin < 1 ||
        effortMax < effortMin) {
      setState(() => _error = 'Enter valid effort values.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<ChallengesService>().create(
        title: _title.text.trim(),
        imageBytes: _imageBytes!,
        imageFilename: _image!.name,
        resources: [
          for (var index = 0; index < _resources.length; index++)
            ChallengeResource(
              id: '',
              title: _resources[index].title.text.trim(),
              url: _resources[index].url.text.trim(),
              resourceType: 'LINK',
              rationale: _resources[index].rationale.text.trim(),
              orderIndex: index,
            ),
        ],
        shortDescription: _shortDescription.text.trim(),
        fullDescription: _fullDescription.text.trim(),
        difficultyLevel: _difficulty,
        estimatedEffortMinMinutes: effortMin,
        estimatedEffortMaxMinutes: effortMax,
        verificationType: 'SELF_REPORTED',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge created as a private draft.')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _image = image;
      _imageBytes = bytes;
      _error = null;
    });
  }

  void _addResource() {
    if (_resources.length >= 20) return;
    setState(() => _resources.add(_ResourceDraft()));
  }

  void _removeResource(int index) {
    if (_resources.length == 1) return;
    final resource = _resources.removeAt(index);
    resource.dispose();
    setState(() {});
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
            Text(
              'Design a small adventure for someone curious.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'At least 3 characters'
                  : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_image == null ? 'Choose image' : 'Change image'),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imageBytes!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortDescription,
              decoration: const InputDecoration(labelText: 'Short description'),
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullDescription,
              decoration: const InputDecoration(
                labelText: 'What will they do?',
              ),
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: const [
                DropdownMenuItem(value: 'BEGINNER', child: Text('Beginner')),
                DropdownMenuItem(
                  value: 'INTERMEDIATE',
                  child: Text('Intermediate'),
                ),
                DropdownMenuItem(value: 'ADVANCED', child: Text('Advanced')),
              ],
              onChanged: (v) => setState(() => _difficulty = v ?? 'BEGINNER'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _effortMin,
              decoration: const InputDecoration(
                labelText: 'Minimum effort (minutes)',
              ),
              keyboardType: TextInputType.number,
              validator: _positiveIntegerValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _effortMax,
              decoration: const InputDecoration(
                labelText: 'Maximum effort (minutes)',
              ),
              keyboardType: TextInputType.number,
              validator: _positiveIntegerValidator,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resources',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_resources.length}/20',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._resources.asMap().entries.map((entry) {
              final index = entry.key;
              final resource = entry.value;
              return Padding(
                key: ValueKey(resource),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Resource ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_resources.length > 1)
                          IconButton(
                            onPressed: _submitting
                                ? null
                                : () => _removeResource(index),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove resource',
                          ),
                      ],
                    ),
                    TextFormField(
                      controller: resource.title,
                      decoration: const InputDecoration(
                        labelText: 'Resource title',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resource.url,
                      decoration: const InputDecoration(
                        labelText: 'Resource URL',
                      ),
                      validator: _httpUrlValidator,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resource.rationale,
                      decoration: const InputDecoration(
                        labelText: 'Why is this resource useful?',
                      ),
                      maxLines: 2,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _submitting || _resources.length >= 20
                  ? null
                  : _addResource,
              icon: const Icon(Icons.add),
              label: const Text('Add resource'),
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

  String? _httpUrlValidator(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri == null || (uri.scheme != 'http' && uri.scheme != 'https')
        ? 'A valid http(s) URL is required'
        : null;
  }
}
