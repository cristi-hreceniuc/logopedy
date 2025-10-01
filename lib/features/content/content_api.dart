// lib/features/content/content_api.dart
import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';

class ContentApi {
  ContentApi(this._dio);
  final Dio _dio;

  Future<List<dynamic>> listModules(int profileId) async {
    final r = await _dio.get(AppConfig.modulesPath(profileId));
    return r.data as List;
  }

  Future<Map<String,dynamic>> getModule(int profileId, int moduleId) async {
    final r = await _dio.get(AppConfig.modulePath(profileId, moduleId));
    return r.data;
  }

  Future<Map<String,dynamic>> getSubmodule(int profileId, int subId) async {
    final r = await _dio.get(AppConfig.submodulePath(profileId, subId));
    return r.data;
  }

  Future<Map<String,dynamic>> getLesson(int profileId, int lessonId) async {
    final r = await _dio.get(AppConfig.lessonPath(profileId, lessonId));
    return r.data;
  }

  Future<Map<String,dynamic>> currentProgress(int profileId) async {
    final r = await _dio.get(AppConfig.progressPath(profileId));
    return r.data;
  }

  Future<Map<String,dynamic>> advance(int profileId, {required int lessonId, required int screenIndex, bool done=false}) async {
    final r = await _dio.post(AppConfig.advancePath(profileId), data: {
      'lessonId': lessonId, 'screenIndex': screenIndex, 'done': done
    });
    return r.data;
  }
}
