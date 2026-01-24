import '../../../core/network/dio_client.dart';
import '../../kid/models/homework_dto.dart';

class HomeworkApi {
  final DioClient _client;
  
  HomeworkApi(this._client);

  /// Get homework assignments for a profile
  Future<List<HomeworkDTO>> getHomework(int profileId) async {
    final response = await _client.dio.get('/api/v1/profiles/$profileId/homework');
    return (response.data as List)
        .map((e) => HomeworkDTO.fromJson(e))
        .toList();
  }

  /// Assign homework to a profile
  Future<HomeworkDTO> assignHomework({
    required int profileId,
    int? moduleId,
    int? submoduleId,
    int? partId,
    DateTime? dueDate,
    String? notes,
  }) async {
    final response = await _client.dio.post('/api/v1/profiles/$profileId/homework', data: {
      if (moduleId != null) 'moduleId': moduleId,
      if (submoduleId != null) 'submoduleId': submoduleId,
      if (partId != null) 'partId': partId,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String().split('T')[0],
      if (notes != null) 'notes': notes,
    });
    return HomeworkDTO.fromJson(response.data);
  }

  /// Remove a homework assignment
  Future<void> removeHomework(int homeworkId) async {
    await _client.dio.delete('/api/v1/homework/$homeworkId');
  }

  /// Mark homework as DONE/CLOSED by specialist (archives it)
  Future<HomeworkDTO> markHomeworkDone(int homeworkId) async {
    final response = await _client.dio.post('/api/v1/homework/$homeworkId/done');
    return HomeworkDTO.fromJson(response.data);
  }
}

