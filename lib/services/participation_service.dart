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
}
