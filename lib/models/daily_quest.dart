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

class DailyQuestRelatedChallenge {
  final String id;
  final String slug;
  final String title;
  final String deepLink;

  const DailyQuestRelatedChallenge({
    required this.id,
    required this.slug,
    required this.title,
    required this.deepLink,
  });

  factory DailyQuestRelatedChallenge.fromJson(Map<String, dynamic> json) =>
      DailyQuestRelatedChallenge(
        id: _string(json['id']),
        slug: _string(json['slug']),
        title: _string(json['title']),
        deepLink: _string(json['deep_link']),
      );
}

class DailyQuestQuizResult {
  final String attemptId;
  final String status;
  final String completionStatus;
  final bool? passed;
  final double? scorePercent;
  final int quizAttemptCount;
  final int quizAttemptsRemaining;
  final int auraAwarded;
  final int dayStreak;
  final String? completionDate;
  final DailyQuestRelatedChallenge? relatedMajorChallenge;

  const DailyQuestQuizResult({
    required this.attemptId,
    required this.status,
    required this.completionStatus,
    required this.quizAttemptCount,
    required this.quizAttemptsRemaining,
    required this.auraAwarded,
    required this.dayStreak,
    this.passed,
    this.scorePercent,
    this.completionDate,
    this.relatedMajorChallenge,
  });

  factory DailyQuestQuizResult.fromJson(Map<String, dynamic> json) {
    final rawScore = json['score_percent'];
    final related = _asMap(json['related_major_challenge']);
    return DailyQuestQuizResult(
      attemptId: _string(json['attempt_id']),
      status: _string(json['status']),
      completionStatus: _string(json['completion_status']),
      passed: json['passed'] is bool ? json['passed'] as bool : null,
      scorePercent: rawScore is num ? rawScore.toDouble() : null,
      quizAttemptCount: _integer(json['quiz_attempt_count']),
      quizAttemptsRemaining: _integer(json['quiz_attempts_remaining']),
      auraAwarded: _integer(json['aura_awarded']),
      dayStreak: _integer(json['day_streak']),
      completionDate: _optionalString(json['completion_date']),
      relatedMajorChallenge: related == null
          ? null
          : DailyQuestRelatedChallenge.fromJson(related),
    );
  }
}

class DailyQuestQuizSession {
  final String sessionId;
  final String attemptId;
  final int attemptNumber;
  final DailyQuestQuestion? question;
  final int? questionIndex;
  final int? questionNumber;
  final int totalQuestions;
  final int secondsPerQuestion;
  final DateTime? answerDeadlineAt;
  final bool timedOut;
  final DailyQuestQuizResult? result;

  const DailyQuestQuizSession({
    required this.sessionId,
    required this.attemptId,
    required this.attemptNumber,
    required this.question,
    required this.questionIndex,
    required this.questionNumber,
    required this.totalQuestions,
    required this.secondsPerQuestion,
    required this.answerDeadlineAt,
    required this.timedOut,
    required this.result,
  });

  factory DailyQuestQuizSession.fromJson(Map<String, dynamic> json) {
    final question = _asMap(json['question']);
    final result = _asMap(json['result']);
    return DailyQuestQuizSession(
      sessionId: _string(json['session_id']),
      attemptId: _string(json['attempt_id']),
      attemptNumber: _integer(json['attempt_number'], fallback: 1),
      question: question == null ? null : DailyQuestQuestion.fromJson(question),
      questionIndex: _nullableInteger(json['question_index']),
      questionNumber: _nullableInteger(json['question_number']),
      totalQuestions: _integer(json['total_questions']),
      secondsPerQuestion: _integer(json['seconds_per_question'], fallback: 30),
      answerDeadlineAt: DateTime.tryParse(_string(json['answer_deadline_at'])),
      timedOut: json['timed_out'] == true,
      result: result == null ? null : DailyQuestQuizResult.fromJson(result),
    );
  }
}

class DailyQuestAttemptResult {
  final String attemptId;
  final String status;
  final String completionStatus;
  final String? questTitle;
  final String? completionDate;
  final DateTime? completedAt;
  final int auraAwarded;
  final int dayStreak;
  final String timezone;
  final double? scorePercent;
  final DailyQuestRelatedChallenge? relatedMajorChallenge;

  const DailyQuestAttemptResult({
    required this.attemptId,
    required this.status,
    required this.completionStatus,
    required this.auraAwarded,
    required this.dayStreak,
    required this.timezone,
    this.questTitle,
    this.completionDate,
    this.completedAt,
    this.scorePercent,
    this.relatedMajorChallenge,
  });

  factory DailyQuestAttemptResult.fromJson(Map<String, dynamic> json) {
    final rawScore = json['score_percent'];
    final related = _asMap(json['related_major_challenge']);
    final quest = _asMap(json['quest']) ?? _asMap(json['daily_quest']);
    return DailyQuestAttemptResult(
      attemptId: _string(json['attempt_id']),
      status: _string(json['status']),
      completionStatus: _string(json['completion_status']),
      questTitle: _optionalString(
        json['quest_title'] ?? json['daily_quest_title'] ?? quest?['title'],
      ),
      completionDate: _optionalString(json['completion_date']),
      completedAt: DateTime.tryParse(_string(json['completed_at'])),
      auraAwarded: _integer(json['aura_awarded']),
      dayStreak: _integer(json['day_streak']),
      timezone: _string(json['timezone'], fallback: 'UTC'),
      scorePercent: rawScore is num ? rawScore.toDouble() : null,
      relatedMajorChallenge: related == null
          ? null
          : DailyQuestRelatedChallenge.fromJson(related),
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
    super.relatedMajorChallenge,
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
      relatedMajorChallenge: quest.relatedMajorChallenge,
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

class AdminDailyQuestAttempt {
  final String id;
  final String questId;
  final String userId;
  final String localDate;
  final String timezone;
  final String status;
  final String? evidenceContentType;
  final String? reviewNote;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const AdminDailyQuestAttempt({
    required this.id,
    required this.questId,
    required this.userId,
    required this.localDate,
    required this.timezone,
    required this.status,
    this.evidenceContentType,
    this.reviewNote,
    this.createdAt,
    this.reviewedAt,
  });

  factory AdminDailyQuestAttempt.fromJson(Map<String, dynamic> json) =>
      AdminDailyQuestAttempt(
        id: _string(json['id']),
        questId: _string(json['quest_id']),
        userId: _string(json['user_id']),
        localDate: _string(json['local_date']),
        timezone: _string(json['timezone'], fallback: 'UTC'),
        status: _string(json['status'], fallback: 'PENDING_REVIEW').toUpperCase(),
        evidenceContentType: _optionalString(json['evidence_content_type']),
        reviewNote: _optionalString(json['review_note']),
        createdAt: DateTime.tryParse(_string(json['created_at'])),
        reviewedAt: DateTime.tryParse(_string(json['reviewed_at'])),
      );
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
  final DailyQuestRelatedChallenge? relatedMajorChallenge;

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
    this.relatedMajorChallenge,
  });

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] ?? json['quiz_questions'];
    final related = _asMap(json['related_challenge']);
    final relatedMajor = _asMap(json['related_major_challenge']);
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
      articleUrl: _optionalString(json['resource_url'] ?? json['article_url']),
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
      relatedMajorChallenge: relatedMajor == null
          ? null
          : DailyQuestRelatedChallenge.fromJson(relatedMajor),
    );
  }
}

class DailyQuestAttempt {
  final String? id;
  final String status;
  final int quizAttemptsUsed;
  final int quizAttemptsRemaining;
  final int? score;
  final bool? passed;
  final String? evidenceStatus;

  const DailyQuestAttempt({
    required this.status,
    this.id,
    this.quizAttemptsUsed = 0,
    this.quizAttemptsRemaining = 0,
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
      id: _optionalString(json['attempt_id'] ?? json['id']),
      status: _string(
        json['status'] ?? json['state'],
        fallback: 'IN_PROGRESS',
      ).toUpperCase(),
      quizAttemptsUsed: _integer(
        json['quiz_attempts_used'] ??
            json['attempts_used'] ??
            json['quiz_attempt_count'],
      ),
      quizAttemptsRemaining: _integer(json['quiz_attempts_remaining']),
        score: parsedScore,
        passed: json['passed'] is bool
          ? json['passed'] as bool
          : json['completed'] is bool
          ? json['completed'] as bool
            : null,
      evidenceStatus: _optionalString(json['evidence_status']),
    );
  }
}

class DailyQuestToday {
  final DailyQuest? quest;
  final String localDate;
  final String timezone;
  final DateTime? expiresAt;
  final DailyQuestAttempt? attempt;

  const DailyQuestToday({
    required this.quest,
    required this.localDate,
    required this.timezone,
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
          : data['attempt_id'] != null || data['status'] != null
          ? {
              'attempt_id': data['attempt_id'],
              'status': data['status'],
              'quiz_attempt_count': data['quiz_attempt_count'],
              'quiz_attempts_remaining': data['quiz_attempts_remaining'],
              'score_percent': data['quiz_score_percent'],
            }
          : null);
    return DailyQuestToday(
      quest: questJson == null ? null : DailyQuest.fromJson(questJson),
      localDate: _string(data['local_date'] ?? data['date']),
      timezone: _string(data['timezone'], fallback: 'UTC'),
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
    timezone: timezone,
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

int? _nullableInteger(Object? value) => value == null
    ? null
    : value is num
    ? value.toInt()
    : int.tryParse('$value');