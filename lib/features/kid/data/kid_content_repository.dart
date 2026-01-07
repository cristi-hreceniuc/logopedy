import '../../../core/network/dio_client.dart';
import '../../content/models/dtos.dart';
import '../../content/models/modules_details_dto.dart';
import '../../content/models/submodule_list_dto.dart';
import '../../content/models/part_dto.dart';

/// Repository for kid-specific content API calls.
/// Uses /kid/* endpoints instead of /content/* endpoints.
class KidContentRepository {
  KidContentRepository(this._client);
  final DioClient _client;

  /// List modules available to the kid
  Future<List<ModuleDto>> modules(int profileId) async {
    final response = await _client.dio.get('/kid/modules');
    return (response.data as List)
        .map((e) => ModuleDto.fromJson(e))
        .toList();
  }

  /// Get module details
  Future<ModuleDetailsDto> moduleDetails(int profileId, int moduleId) async {
    final response = await _client.dio.get('/kid/modules/$moduleId');
    return ModuleDetailsDto.fromJson(response.data);
  }

  /// Get submodule with parts
  Future<SubmoduleListDto> submoduleWithParts(int profileId, int subId) async {
    final response = await _client.dio.get('/kid/submodules/$subId');
    return SubmoduleListDto.fromJson(response.data);
  }

  /// Get part with lessons
  Future<PartDto> getPart(int profileId, int partId) async {
    final response = await _client.dio.get('/kid/parts/$partId');
    return PartDto.fromJson(response.data);
  }

  /// Get lesson for playing
  Future<LessonDto> getLesson(int profileId, int lessonId) async {
    final response = await _client.dio.get('/kid/lessons/$lessonId');
    return LessonDto.fromJson(response.data);
  }

  /// Get current progress
  Future<ProgressDto> current(int profileId) async {
    final response = await _client.dio.get('/kid/progress');
    return ProgressDto.fromJson(response.data);
  }

  /// Advance progress
  Future<AdvanceResp> advance(
    int profileId, {
    required int lessonId,
    required int screenIndex,
    bool done = false,
  }) async {
    final response = await _client.dio.post('/kid/progress', data: {
      'lessonId': lessonId,
      'screenIndex': screenIndex,
      'done': done,
    });
    return AdvanceResp.fromJson(response.data);
  }
}

