// lib/features/content/content_repository.dart
import '../../core/network/dio_client.dart';
import 'content_api.dart';
import 'models/dtos.dart';
import 'models/modules_details_dto.dart';
import 'models/submodule_list_dto.dart';
import 'models/part_dto.dart';

class ContentRepository {
  ContentRepository(DioClient client) : _api = ContentApi(client.dio);
  final ContentApi _api;

  Future<List<ModuleDto>> modules(int profileId, {String? targetAudience}) async =>
      (await _api.listModules(profileId, targetAudience: targetAudience))
          .map((e) => ModuleDto.fromJson(e))
          .toList()
          .cast<ModuleDto>();

  Future<SubmoduleDto> submodule(int profileId, int subId, {bool forceRefresh = false}) async =>
      SubmoduleDto.fromJson(await _api.getSubmodule(profileId, subId, forceRefresh: forceRefresh));

  Future<SubmoduleListDto> submoduleWithParts(int profileId, int subId, {bool forceRefresh = false}) async =>
      SubmoduleListDto.fromJson(await _api.getSubmodule(profileId, subId, forceRefresh: forceRefresh));

  Future<PartDto> getPart(int profileId, int partId, {bool forceRefresh = false}) async =>
      PartDto.fromJson(await _api.getPart(profileId, partId, forceRefresh: forceRefresh));

  /// Lecția cu ecrane (pentru player)
  Future<LessonDto> getLesson(int profileId, int lessonId) async =>
      LessonDto.fromJson(await _api.getLesson(profileId, lessonId));

  Future<ProgressDto> current(int profileId) async =>
      ProgressDto.fromJson(await _api.currentProgress(profileId));

  Future<AdvanceResp> advance(
      int profileId, {
        required int lessonId,
        required int screenIndex,
        bool done = false,
      }) async =>
      AdvanceResp.fromJson(
          await _api.advance(profileId, lessonId: lessonId, screenIndex: screenIndex, done: done));

  Future<ModuleDetailsDto> moduleDetails(int profileId, int moduleId) async =>
      ModuleDetailsDto.fromJson(await _api.getModule(profileId, moduleId));
}
