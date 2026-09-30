import '../models/progress_log.dart';
import '../models/participation.dart';
import 'api_client.dart';

class ParticipationService {
  final ApiClient api;
  ParticipationService(this.api);

  Future<List<Participation>> listMine() async {
    final data = await api.get('/participation/me');
    return (data as List).map((e) => Participation.fromJson(e)).toList();
  }

  Future<Participation> accept(String slug) async {
    final data = await api.post('/participation/challenges/$slug/accept');
    return Participation.fromJson(data);
  }

  Future<Participation> updateStatus(
    String participantId,
    String status,
  ) async {
    final data = await api.patch(
      '/participation/$participantId',
      data: {'status': status},
    );
    return Participation.fromJson(data);
  }

  Future<ProgressLog> logProgress(
    String participantId, {
    required double hoursSpent,
    String? note,
  }) async {
    final data = await api.post(
      '/participation/$participantId/progress',
      data: {'hours_spent': hoursSpent, 'note': note},
    );
    return ProgressLog.fromJson(data);
  }

  Future<ResourceCompletion> completeResource(
    String participantId, {
    required String milestoneId,
    required String resourceId,
    required int resourceMinutes,
    String? note,
    bool logProgress = false,
  }) async {
    final data = await api.post(
      '/participation/$participantId/milestones/$milestoneId/resources/$resourceId/complete',
      data: {
        'resource_minutes': resourceMinutes,
        'note': note,
        'log_progress': logProgress,
      },
    );
    final response = _responseMap(data);
    return ResourceCompletion.fromJson(
      response ??
          {
            'resource_id': resourceId,
            'milestone_id': milestoneId,
            'completed': true,
          },
    );
  }

  Future<MetricAttempt> logMetricAttempt(
    String participantId, {
    required String metricKey,
    required double value,
    required String unit,
    String? note,
  }) async {
    final data = await api.post(
      '/participation/$participantId/metric-attempts',
      data: {
        'metric_key': metricKey,
        'value': value,
        'unit': unit,
        'note': note,
      },
    );
    final response = _responseMap(data);
    return MetricAttempt.fromJson(
      response ?? {'metric_key': metricKey, 'value': value, 'unit': unit},
    );
  }

  Future<List<ProgressLog>> listProgress(
    String participantId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await api.get(
      '/participation/$participantId/progress',
      query: {'limit': limit, 'offset': offset},
    );
    return (data as List).map((e) => ProgressLog.fromJson(e)).toList();
  }

  Map<String, dynamic>? _responseMap(dynamic data) {
    if (data is! Map) return null;
    final nested = data['data'] ?? data['result'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return Map<String, dynamic>.from(data);
  }
}
