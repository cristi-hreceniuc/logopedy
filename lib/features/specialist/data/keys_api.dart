import '../../../core/network/dio_client.dart';
import '../models/license_key_dto.dart';
import '../models/key_stats_dto.dart';

class KeysApi {
  final DioClient _client;
  
  KeysApi(this._client);

  /// Get all license keys for the authenticated specialist
  Future<List<LicenseKeyDTO>> listKeys() async {
    final response = await _client.dio.get('/api/v1/keys');
    return (response.data as List)
        .map((e) => LicenseKeyDTO.fromJson(e))
        .toList();
  }

  /// Get key statistics
  Future<KeyStatsDTO> getKeyStats() async {
    final response = await _client.dio.get('/api/v1/keys/stats');
    return KeyStatsDTO.fromJson(response.data);
  }

  /// Activate a key by linking it to a profile
  Future<void> activateKey(int keyId, int profileId) async {
    await _client.dio.post('/api/v1/keys/$keyId/activate', data: {'profileId': profileId});
  }

  /// Reset a key (delete profile and progress, unlink key)
  Future<void> resetKey(int keyId) async {
    await _client.dio.post('/api/v1/keys/$keyId/reset');
  }
}

