import '../models/challenge_detail.dart';
import 'api_client.dart';

class IntegrationsService {
  final ApiClient api;
  IntegrationsService(this.api);

  Future<VerificationProvider> connect(String providerId) async {
    final data = await api.post('/integrations/$providerId/connect');
    return _providerFromResponse(data, providerId);
  }

  Future<VerificationProvider> getStatus(String providerId) async {
    final data = await api.get('/integrations/$providerId/status');
    return _providerFromResponse(data, providerId);
  }

  VerificationProvider _providerFromResponse(dynamic data, String providerId) {
    final response = Map<String, dynamic>.from(data as Map);
    return VerificationProvider(
      id: response['provider_id']?.toString() ?? providerId,
      name: response['provider_name']?.toString() ?? providerId,
      connectUrl: response['connect_url']?.toString() ?? '',
      connected: response['connected'] == true,
      account: response['account'] is Map
          ? VerificationAccount.fromJson(
              Map<String, dynamic>.from(response['account'] as Map),
            )
          : null,
    );
  }
}