// lib/features/profiles/data/profiles_repository.dart
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import 'models/profile_model.dart';

class ProfilesRepository {
  ProfilesRepository(DioClient client): _dio = client.dio;
  final Dio _dio;

  Future<List<ProfileCardDto>> list() async {
    final r = await _dio.get('/api/profiles'); // ruta ta existentă
    final list = (r.data as List).cast<Map<String, dynamic>>();
    return list.map(ProfileCardDto.fromJson).toList();
  }

  Future<List<LessonProgressDto>> lessonProgress(int profileId) async {
    final r = await _dio.get('/api/profiles/$profileId/lessons-progress');
    final list = (r.data as List).cast<Map<String,dynamic>>();
    return list.map(LessonProgressDto.fromJson).toList();
  }

  Future<ProfileCardDto> create({required String name, String? avatarUri}) async {
    final r = await _dio.post('/api/profiles', data: {'name': name, 'avatarUri': avatarUri});
    return ProfileCardDto.fromJson(r.data as Map<String,dynamic>);
  }
}
