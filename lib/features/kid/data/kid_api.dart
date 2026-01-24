import '../../../core/network/dio_client.dart';
import '../models/kid_login_response.dart';
import '../models/homework_dto.dart';

class KidApi {
  final DioClient _client;
  
  KidApi(this._client);

  /// Login with license key
  Future<KidLoginResponse> loginWithKey(String key) async {
    final response = await _client.dio.post('/api/v1/auth/kid-login', data: {'key': key});
    return KidLoginResponse.fromJson(response.data);
  }

  /// Refresh kid's access token
  Future<KidLoginResponse> refreshToken(String refreshToken) async {
    final response = await _client.dio.post('/api/v1/auth/kid-refresh', data: {'refreshToken': refreshToken});
    return KidLoginResponse.fromJson(response.data);
  }

  /// Get homework assignments for the kid
  Future<List<HomeworkDTO>> getHomework() async {
    final response = await _client.dio.get('/api/v1/kid/homework');
    return (response.data as List)
        .map((e) => HomeworkDTO.fromJson(e))
        .toList();
  }

  /// Mark homework as complete
  Future<HomeworkDTO> markHomeworkComplete(int homeworkId) async {
    final response = await _client.dio.post('/api/v1/kid/homework/$homeworkId/complete');
    return HomeworkDTO.fromJson(response.data);
  }

  /// Mark homework as incomplete
  Future<HomeworkDTO> markHomeworkIncomplete(int homeworkId) async {
    final response = await _client.dio.post('/api/v1/kid/homework/$homeworkId/incomplete');
    return HomeworkDTO.fromJson(response.data);
  }

  /// Get kid's progress
  Future<Map<String, dynamic>> getProgress() async {
    final response = await _client.dio.get('/api/v1/kid/progress');
    return response.data;
  }

  /// Advance progress (complete a lesson screen)
  Future<Map<String, dynamic>> advanceProgress({
    required int lessonId,
    required int screenIndex,
    required bool done,
  }) async {
    final response = await _client.dio.post('/api/v1/kid/progress', data: {
      'lessonId': lessonId,
      'screenIndex': screenIndex,
      'done': done,
    });
    return response.data;
  }

  // ============ Content APIs for Kids ============

  /// Get all modules available to this kid
  Future<List<dynamic>> listModules() async {
    final response = await _client.dio.get('/api/v1/kid/modules');
    return response.data as List;
  }

  /// Get a specific module with its submodules
  Future<Map<String, dynamic>> getModule(int moduleId) async {
    final response = await _client.dio.get('/api/v1/kid/modules/$moduleId');
    return response.data;
  }

  /// Get a submodule with its parts
  Future<Map<String, dynamic>> getSubmodule(int submoduleId, {bool forceRefresh = false}) async {
    final path = '/api/v1/kid/submodules/$submoduleId';
    final url = forceRefresh 
        ? '$path?t=${DateTime.now().millisecondsSinceEpoch}'
        : path;
    final response = await _client.dio.get(url);
    return response.data;
  }

  /// Get a part with its lessons
  Future<Map<String, dynamic>> getPart(int partId, {bool forceRefresh = false}) async {
    final path = '/api/v1/kid/parts/$partId';
    final url = forceRefresh 
        ? '$path?t=${DateTime.now().millisecondsSinceEpoch}'
        : path;
    final response = await _client.dio.get(url);
    return response.data;
  }

  /// Get a lesson for playing
  Future<Map<String, dynamic>> getLesson(int lessonId) async {
    final response = await _client.dio.get('/api/v1/kid/lessons/$lessonId');
    return response.data;
  }
}

