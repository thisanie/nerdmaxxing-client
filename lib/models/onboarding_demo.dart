import 'challenge.dart';
import 'challenge_detail.dart';
import 'participation.dart';

class OnboardingDemoData {
  static final challenge = Challenge(
    id: 'onboarding-handstand',
    title: 'Hold a Handstand for 30 Seconds',
    resources: const [],
    slug: 'handstand-30-seconds',
    shortDescription: 'Build a steady, confident handstand.',
    fullDescription:
        'Build balance and control through a few focused practice milestones.',
    creatorId: 'nerdmaxxing',
    difficultyLevel: 'BEGINNER',
    auraPoints: 40,
    status: 'PUBLISHED',
    visibility: 'PUBLIC',
    estimatedEffortMinMinutes: 15,
    estimatedDurationMinutes: 21 * 24 * 60,
    verificationType: 'VIDEO',
    metrics: const [
      ChallengeMetric(
        key: 'hold_seconds',
        label: 'Handstand hold',
        kind: 'DURATION',
        unit: 'seconds',
        target: 30,
        current: 18,
        direction: 'AT_LEAST',
        isPrimary: true,
        format: 'INTEGER',
      ),
    ],
  );

  static final participation = Participation(
    id: 'onboarding-participation',
    challengeId: challenge.id,
    userId: 'onboarding-user',
    status: 'IN_PROGRESS',
    completionStatus: 'NOT_COMPLETED',
    verificationStatus: 'NOT_REQUIRED',
  );

  static ChallengeDetail detail({
    bool milestonesComplete = false,
    bool hasLoggedProgress = false,
  }) {
    const titles = [
      'Build your foundation',
      'Find your balance',
      'Hold the line',
    ];
    const descriptions = [
      'Warm up your wrists and shoulders.',
      'Practice controlled wall kick-ups.',
      'Hold steady, then capture your proof.',
    ];

    final milestones = [
      for (var index = 0; index < titles.length; index++)
        ChallengeMilestone(
          id: 'onboarding-milestone-${index + 1}',
          orderIndex: index + 1,
          title: titles[index],
          description: descriptions[index],
          status: milestonesComplete ? 'COMPLETED' : 'IN_PROGRESS',
          currentValue: index == 0 && hasLoggedProgress ? 18 : 0,
          targetValue: 30,
          completedResourceCount: milestonesComplete ? 2 : 0,
          totalResourceCount: 2,
          loggedMinutes: index == 0 && hasLoggedProgress ? 12 : 0,
          resources: [
            for (var resourceIndex = 0; resourceIndex < 2; resourceIndex++)
              ChallengeResource(
                id: 'onboarding-resource-${index + 1}-$resourceIndex',
                title: resourceIndex == 0
                    ? 'Prepare your body'
                    : 'Practice the movement',
                url: 'https://example.invalid/onboarding',
                resourceType: 'PRACTICE',
                rationale: 'A short guided practice step.',
                orderIndex: resourceIndex + 1,
                completed: milestonesComplete,
              ),
          ],
        ),
    ];

    return ChallengeDetail(
      challenge: challenge,
      metrics: challenge.metrics,
      milestones: milestones,
      attempts: hasLoggedProgress
          ? [
              ChallengeAttempt(
                id: 'onboarding-attempt',
                metrics: const {'hold_seconds': 18},
                note: 'First controlled hold logged.',
                meetsTarget: false,
                createdAt: DateTime(2026, 11, 26),
              ),
            ]
          : const [],
      participantCount: 128,
      completedParticipantCount: 37,
      progress: ChallengeProgressSnapshot(
        currentValue: hasLoggedProgress ? 18 : 0,
        targetValue: 30,
        unit: 'seconds',
        completedMilestoneCount: milestonesComplete ? 3 : 0,
        totalMilestoneCount: 3,
        loggedMinutes: hasLoggedProgress ? 12 : 0,
        challengeStatus: milestonesComplete ? 'COMPLETED' : 'ACTIVE',
        readyForProof: milestonesComplete,
      ),
      verification: const ChallengeVerification(
        type: 'VIDEO',
        kind: 'VIDEO',
        requiredRuns: 1,
        instructions: 'Show a clear, uninterrupted handstand hold.',
        evidence: VerificationEvidenceRules(
          allowedTypes: ['VIDEO'],
          requiresFile: true,
          requiresExplanation: true,
          allowedMimeTypes: ['video/mp4'],
        ),
      ),
    );
  }
}