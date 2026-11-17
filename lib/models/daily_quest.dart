class DailyQuestQuestion {
  final String prompt;
  final List<String> options;

  const DailyQuestQuestion({required this.prompt, required this.options});

  factory DailyQuestQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return DailyQuestQuestion(
      prompt: json['prompt']?.toString() ?? '',
      options: rawOptions is List
          ? rawOptions.map((option) => option.toString()).toList()
          : const [],
    );
  }
}

class AdminDailyQuest extends DailyQuest {
  final String status;
  final String? scheduledLocalDate;
  final List<AdminDailyQuestQuestion> answerKey;

  const AdminDailyQuest({
    required super.id,
    required super.title,
    required super.description,
    required super.instructions,
    required super.category,
    required super.estimatedMinutes,
    required super.verificationType,
    required super.auraReward,
    super.articleUrl,
    super.questions,
    super.relatedChallengeId,
    super.relatedChallengeSlug,
    super.relatedChallengeTitle,
    required this.status,
    this.scheduledLocalDate,
    this.answerKey = const [],
  });

  factory AdminDailyQuest.fromJson(Map<String, dynamic> json) {
    final quest = DailyQuest.fromJson(json);
    final rawQuestions = json['questions'];
    return AdminDailyQuest(
      id: quest.id,
      title: quest.title,
      description: quest.description,
      instructions: quest.instructions,
      category: quest.category,
      estimatedMinutes: quest.estimatedMinutes,
      verificationType: quest.verificationType,
      auraReward: quest.auraReward,
      articleUrl: quest.articleUrl,
      questions: quest.questions,
      relatedChallengeId: quest.relatedChallengeId,
      relatedChallengeSlug: quest.relatedChallengeSlug,
      relatedChallengeTitle: quest.relatedChallengeTitle,
      status: _string(
        json['status'] ?? json['publication_status'],
        fallback: 'DRAFT',
      ).toUpperCase(),
      scheduledLocalDate: _optionalString(
        json['scheduled_local_date'] ?? json['local_date'],
      ),
      answerKey: rawQuestions is List
          ? rawQuestions
                .whereType<Map>()
                .map(
                  (question) => AdminDailyQuestQuestion.fromJson(
                    Map<String, dynamic>.from(question),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class AdminDailyQuestQuestion {
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;

  const AdminDailyQuestQuestion({
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
  });

  factory AdminDailyQuestQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return AdminDailyQuestQuestion(
      prompt: _string(json['prompt']),
      options: rawOptions is List
          ? rawOptions.map((option) => option.toString()).toList()
          : const [],
      correctOptionIndex: _integer(json['correct_option_index']),
    );
  }
}

class DailyQuest {
  final String id;
  final String title;
  final String description;
  final String instructions;
  final String category;
  final int estimatedMinutes;
  final String verificationType;
  final String? articleUrl;
  final int auraReward;
  final List<DailyQuestQuestion> questions;
  final String? relatedChallengeId;
  final String? relatedChallengeSlug;
  final String? relatedChallengeTitle;

  const DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.category,
    required this.estimatedMinutes,
    required this.verificationType,
    required this.auraReward,
    this.articleUrl,
    this.questions = const [],
    this.relatedChallengeId,
    this.relatedChallengeSlug,
    this.relatedChallengeTitle,
  });

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] ?? json['quiz_questions'];
    final related = _asMap(json['related_challenge']);
    return DailyQuest(
      id: _string(json['id'] ?? json['quest_id']),
      title: _string(json['title'], fallback: 'Daily Quest'),
      description: _string(
        json['short_description'] ?? json['description'],
      ),
      instructions: _string(json['instructions'] ?? json['full_description']),
      category: _string(json['category'], fallback: 'KNOWLEDGE').toUpperCase(),
      estimatedMinutes: _integer(
        json['estimated_minutes'] ?? json['estimated_time_minutes'],
        fallback: 10,
      ),
      verificationType: _string(
        json['verification_type'],
        fallback: 'QUIZ',
      ).toUpperCase(),
      articleUrl: _optionalString(json['article_url']),
      auraReward: _integer(json['aura_reward'] ?? json['aura_points'], fallback: 2),
      questions: rawQuestions is List
          ? rawQuestions
                .whereType<Map>()
                .map(
                  (question) => DailyQuestQuestion.fromJson(
                    Map<String, dynamic>.from(question),
                  ),
                )
                .toList()
          : const [],
      relatedChallengeId: _optionalString(
        json['related_challenge_id'] ?? related?['id'],
      ),
      relatedChallengeSlug: _optionalString(
        json['related_challenge_slug'] ?? related?['slug'],
      ),
      relatedChallengeTitle: _optionalString(
        json['related_challenge_title'] ?? related?['title'],
      ),
    );
  }
}

class DailyQuestAttempt {
  final String status;
  final int quizAttemptsUsed;
  final int? score;
  final bool? passed;
  final String? evidenceStatus;

  const DailyQuestAttempt({
    required this.status,
    this.quizAttemptsUsed = 0,
    this.score,
    this.passed,
    this.evidenceStatus,
  });

  bool get isCompleted =>
      status == 'COMPLETED' || status == 'APPROVED' || passed == true;
  bool get isPendingReview =>
      status == 'PENDING_REVIEW' ||
      evidenceStatus?.toUpperCase() == 'PENDING_REVIEW';
  bool get isFailed => status == 'FAILED' || status == 'EXPIRED';

  factory DailyQuestAttempt.fromJson(Map<String, dynamic> json) {
    final rawScore = json['score'] ?? json['score_percent'];
    final parsedScore = rawScore is num
      ? (rawScore <= 1 ? (rawScore * 100).round() : rawScore.round())
      : int.tryParse('$rawScore');
    return DailyQuestAttempt(
      status: _string(
        json['status'] ?? json['state'],
        fallback: 'IN_PROGRESS',
      ).toUpperCase(),
      quizAttemptsUsed: _integer(
        json['quiz_attempts_used'] ??
            json['attempts_used'] ??
            json['quiz_attempt_count'],
      ),
        score: parsedScore,
        passed: json['passed'] is bool
          ? json['passed'] as bool
          : json['completed'] is bool
          ? json['completed'] as bool
          : parsedScore == null
          ? null
          : parsedScore >= 80,
      evidenceStatus: _optionalString(json['evidence_status']),
    );
  }
}

class DailyQuestToday {
  final DailyQuest? quest;
  final String localDate;
  final DateTime? expiresAt;
  final DailyQuestAttempt? attempt;

  const DailyQuestToday({
    required this.quest,
    required this.localDate,
    required this.expiresAt,
    required this.attempt,
  });

  factory DailyQuestToday.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']) ?? json;
    final questJson =
        _asMap(data['quest']) ??
        _asMap(data['daily_quest']) ??
      _asMap(data['today']) ??
      (data['title'] != null && data['id'] != null ? data : null);
    final rawAttemptState = data['attempt_state'];
    final attemptJson =
        _asMap(data['attempt']) ??
        _asMap(data['current_attempt']) ??
      _asMap(rawAttemptState) ??
      (rawAttemptState is String
        ? {
          'status': rawAttemptState,
          'quiz_attempts_used': data['quiz_attempts_used'],
          'score': data['score'],
          'evidence_status': data['evidence_status'],
          }
        : null);
    return DailyQuestToday(
      quest: questJson == null ? null : DailyQuest.fromJson(questJson),
      localDate: _string(data['local_date'] ?? data['date']),
      expiresAt: DateTime.tryParse(
        _string(data['expires_at'] ?? data['expires_at_utc']),
      ),
      attempt: attemptJson == null
          ? null
          : DailyQuestAttempt.fromJson(attemptJson),
    );
  }

  DailyQuestToday withAttempt(DailyQuestAttempt attempt) => DailyQuestToday(
    quest: quest,
    localDate: localDate,
    expiresAt: expiresAt,
    attempt: attempt,
  );
}

Map<String, dynamic>? _asMap(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : null;

String _string(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

String? _optionalString(Object? value) {
  final result = value?.toString();
  return result == null || result.isEmpty ? null : result;
}

int _integer(Object? value, {int fallback = 0}) => value is num
    ? value.toInt()
    : int.tryParse('$value') ?? fallback;