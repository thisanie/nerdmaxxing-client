import 'package:flutter/material.dart' hide SnackBar;
import 'package:provider/provider.dart';

import '../../models/daily_quest.dart';
import '../../services/api_client.dart';
import '../../services/daily_quests_service.dart';
import '../../widgets/app_error.dart';
import '../../widgets/app_snack_bar.dart';

class _QuestQuestionDraft {
  final prompt = TextEditingController();
  final options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  int correctOptionIndex = 0;

  void dispose() {
    prompt.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class AdminDailyQuestsScreen extends StatefulWidget {
  const AdminDailyQuestsScreen({super.key});

  @override
  State<AdminDailyQuestsScreen> createState() => _AdminDailyQuestsScreenState();
}

class _AdminDailyQuestsScreenState extends State<AdminDailyQuestsScreen> {
  static const _categories = [
    'KNOWLEDGE',
    'PHYSICAL',
    'CREATIVE',
    'PRACTICAL',
    'MENTAL',
  ];
  static const _verificationTypes = ['QUIZ', 'IMAGE', 'VIDEO'];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _instructions = TextEditingController();
  final _articleUrl = TextEditingController();
  final _relatedChallengeId = TextEditingController();
  final _questions = <_QuestQuestionDraft>[_QuestQuestionDraft()];

  List<AdminDailyQuest> _quests = [];
  bool _loading = true;
  bool _creating = false;
  final _schedulingIds = <String>{};
  String _category = 'KNOWLEDGE';
  String _verificationType = 'QUIZ';
  int _estimatedMinutes = 10;
  int _auraReward = 2;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _instructions,
      _articleUrl,
      _relatedChallengeId,
    ]) {
      controller.dispose();
    }
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quests = await context.read<DailyQuestsService>().listAdminQuests();
      if (mounted) setState(() => _quests = quests);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDraft() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verificationType == 'QUIZ' && !_validateQuestions()) return;

    final articleUrl = _articleUrl.text.trim();
    final challengeId = _relatedChallengeId.text.trim();
    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'short_description': _description.text.trim(),
      'instructions': _instructions.text.trim(),
      'category': _category,
      'estimated_minutes': _estimatedMinutes,
      'verification_type': _verificationType,
      'aura_reward': _auraReward,
      if (articleUrl.isNotEmpty) 'resource_url': articleUrl,
      if (challengeId.isNotEmpty) 'related_challenge_id': challengeId,
      if (_verificationType == 'QUIZ')
        'questions': [
          for (final question in _questions)
            {
              'prompt': question.prompt.text.trim(),
              'options': question.options
                  .map((option) => option.text.trim())
                  .toList(),
              'correct_option_index': question.correctOptionIndex,
            },
        ],
    };

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final quest = await context
          .read<DailyQuestsService>()
          .createAdminDraft(payload: payload);
      if (!mounted) return;
      _resetForm();
      await _loadQuests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${quest.title}" as a draft.')),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  bool _validateQuestions() {
    for (var index = 0; index < _questions.length; index++) {
      final question = _questions[index];
      if (question.prompt.text.trim().isEmpty ||
          question.options.any((option) => option.text.trim().isEmpty)) {
        setState(() {
          _error = 'Complete the prompt and all options for question ${index + 1}.';
        });
        return false;
      }
      if (question.correctOptionIndex >= question.options.length) {
        setState(() => _error = 'Choose a correct answer for question ${index + 1}.');
        return false;
      }
    }
    setState(() => _error = null);
    return true;
  }

  void _resetForm() {
    _title.clear();
    _description.clear();
    _instructions.clear();
    _articleUrl.clear();
    _relatedChallengeId.clear();
    for (final question in _questions) {
      question.dispose();
    }
    _questions
      ..clear()
      ..add(_QuestQuestionDraft());
    _category = 'KNOWLEDGE';
    _verificationType = 'QUIZ';
    _estimatedMinutes = 10;
    _auraReward = 2;
    _error = null;
    setState(() {});
  }

  Future<void> _scheduleQuest(AdminDailyQuest quest) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Schedule Daily Quest',
    );
    if (selectedDate == null || !mounted) return;

    setState(() => _schedulingIds.add(quest.id));
    try {
      await context.read<DailyQuestsService>().scheduleAdminQuest(
        questId: quest.id,
        localDate: selectedDate,
      );
      if (!mounted) return;
      await _loadQuests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scheduled for ${_formatDate(selectedDate)}.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) AppErrorSnackbar.show(context, error);
    } finally {
      if (mounted) setState(() => _schedulingIds.remove(quest.id));
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _addQuestion() {
    if (_questions.length >= 30) return;
    setState(() => _questions.add(_QuestQuestionDraft()));
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    final removed = _questions.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _addOption(_QuestQuestionDraft question) {
    if (question.options.length >= 6) return;
    setState(() => question.options.add(TextEditingController()));
  }

  void _removeOption(_QuestQuestionDraft question, int index) {
    if (question.options.length <= 2) return;
    final removed = question.options.removeAt(index);
    removed.dispose();
    if (question.correctOptionIndex == index) {
      question.correctOptionIndex = 0;
    } else if (question.correctOptionIndex > index) {
      question.correctOptionIndex--;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Quests'),
        actions: [
          IconButton(
            tooltip: 'Refresh quests',
            onPressed: _loading ? null : _loadQuests,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuests,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildCreateForm(),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quest library', style: Theme.of(context).textTheme.titleLarge),
                Text('${_quests.length}', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && _quests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_quests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No Daily Quest drafts yet.')),
              )
            else
              for (final quest in _quests) _buildQuestTile(quest),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create a draft', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _requiredValidator,
              ),
              TextFormField(
                controller: _description,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _requiredValidator,
              ),
              TextFormField(
                controller: _instructions,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Instructions'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(_humanize(category)),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _verificationType,
                decoration: const InputDecoration(labelText: 'Verification'),
                items: [
                  for (final type in _verificationTypes)
                    DropdownMenuItem(value: type, child: Text(_humanize(type))),
                ],
                onChanged: (value) => setState(() => _verificationType = value!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _estimatedMinutes,
                      decoration: const InputDecoration(labelText: 'Minutes'),
                      items: [
                        for (var minutes = 5; minutes <= 15; minutes++)
                          DropdownMenuItem(
                            value: minutes,
                            child: Text('$minutes min'),
                          ),
                      ],
                      onChanged: (value) => setState(() => _estimatedMinutes = value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _auraReward,
                      decoration: const InputDecoration(labelText: 'Aura reward'),
                      items: [
                        for (var reward = 1; reward <= 10; reward++)
                          DropdownMenuItem(
                            value: reward,
                            child: Text('$reward Aura'),
                          ),
                      ],
                      onChanged: (value) => setState(() => _auraReward = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _articleUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Article URL (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relatedChallengeId,
                decoration: const InputDecoration(
                  labelText: 'Related Major Challenge ID (optional)',
                ),
              ),
              if (_verificationType == 'QUIZ') ...[
                const SizedBox(height: 18),
                _buildQuestionEditor(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _creating ? null : _createDraft,
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_creating ? 'Saving draft...' : 'Save as draft'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Quiz questions', style: Theme.of(context).textTheme.titleMedium),
          Text('${_questions.length}', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
      const SizedBox(height: 8),
      for (var index = 0; index < _questions.length; index++)
        _buildQuestionCard(_questions[index], index),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _questions.length >= 30 ? null : _addQuestion,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add question'),
        ),
      ),
    ],
  );

  Widget _buildQuestionCard(_QuestQuestionDraft question, int questionIndex) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${questionIndex + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_questions.length > 1)
                  IconButton(
                    tooltip: 'Remove question',
                    onPressed: () => _removeQuestion(questionIndex),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            TextField(
              controller: question.prompt,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Prompt'),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: question.correctOptionIndex,
              onChanged: (value) => setState(
                () => question.correctOptionIndex = value ?? 0,
              ),
              child: Column(
                children: [
                  for (var optionIndex = 0;
                      optionIndex < question.options.length;
                      optionIndex++)
                    Row(
                      children: [
                        Radio<int>(value: optionIndex),
                        Expanded(
                          child: TextField(
                            controller: question.options[optionIndex],
                            decoration: InputDecoration(
                              labelText: 'Option ${optionIndex + 1}',
                              isDense: true,
                            ),
                          ),
                        ),
                        if (question.options.length > 2)
                          IconButton(
                            tooltip: 'Remove option',
                            onPressed: () => _removeOption(question, optionIndex),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: question.options.length >= 6
                    ? null
                    : () => _addOption(question),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add option'),
              ),
            ),
            Text(
              'Select the radio button beside the correct answer.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestTile(AdminDailyQuest quest) {
    final isDraft = quest.status == 'DRAFT';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(quest.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_humanize(quest.category)} · ${_humanize(quest.verificationType)} · ${quest.status}'
          '${quest.scheduledLocalDate == null ? '' : ' · ${quest.scheduledLocalDate}'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          _detailRow('Description', quest.description),
          _detailRow('Instructions', quest.instructions),
          _detailRow('Estimated time', '${quest.estimatedMinutes} minutes'),
          _detailRow('Aura reward', '${quest.auraReward}'),
          if (quest.articleUrl != null)
            _detailRow('Article URL', quest.articleUrl!),
          if (quest.relatedChallengeId != null)
            _detailRow('Related challenge', quest.relatedChallengeId!),
          if (quest.verificationType == 'QUIZ') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Answer key', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < quest.answerKey.length; index++)
              _answerKeyRow(quest.answerKey[index], index),
          ],
          if (isDraft) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _schedulingIds.contains(quest.id)
                    ? null
                    : () => _scheduleQuest(quest),
                icon: _schedulingIds.contains(quest.id)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_month_rounded),
                label: const Text('Schedule'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _answerKeyRow(AdminDailyQuestQuestion question, int index) {
    final correctAnswer = question.correctOptionIndex >= 0 &&
            question.correctOptionIndex < question.options.length
        ? question.options[question.correctOptionIndex]
        : 'Unavailable';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}. ${question.prompt}'),
          Text(
            'Answer: $correctAnswer',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
      ],
    ),
  );

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String _humanize(String value) => value
      .split('_')
      .map((word) => word.isEmpty
          ? word
          : '${word[0]}${word.substring(1).toLowerCase()}')
      .join(' ');
}