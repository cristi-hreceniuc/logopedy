// lib/features/profiles/data/profiles_api.dart
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';

class ProfilesApi {
  ProfilesApi(this._dio);
  final Dio _dio;

  Future<List<dynamic>> listProfiles() async {
    final r = await _dio.get('/api/profiles');
    return r.data as List;
  }

  Future<Map<String,dynamic>> createProfile({required String name, String? avatarUri}) async {
    final r = await _dio.post('/api/profiles', data: {'name': name, 'avatarUri': avatarUri});
    return r.data as Map<String,dynamic>;
  }

  Future<List<dynamic>> lessonProgress(int profileId) async {
    final r = await _dio.get('/api/profiles/$profileId/lessons-progress');
    return r.data as List;
  }
}
