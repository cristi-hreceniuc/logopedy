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
    
    print('📥 Profile list response: ${list.length} profiles');
    for (var i = 0; i < list.length; i++) {
      print('📥 Profile $i raw data: ${list[i]}');
    }
    
    final profiles = list.map(ProfileCardDto.fromJson).toList();
    
    for (var i = 0; i < profiles.length; i++) {
      print('📥 Profile $i parsed - birthDate: ${profiles[i].birthDate}, gender: ${profiles[i].gender}');
    }
    
    return profiles;
  }

  Future<List<LessonProgressDto>> lessonProgress(int profileId) async {
    final r = await _dio.get('/api/profiles/$profileId/lessons-progress');
    final list = (r.data as List).cast<Map<String,dynamic>>();
    return list.map(LessonProgressDto.fromJson).toList();
  }

  Future<ProfileCardDto> create({
    required String name,
    String? avatarUri,
    required DateTime birthDate,
    required String gender,
  }) async {
    final requestData = {
      'name': name,
      if (avatarUri != null) 'avatarUri': avatarUri,
      'birthday': birthDate.toIso8601String(),
      'gender': gender,
    };
    
    print('📤 Creating profile with data: $requestData');
    print('📤 birthDate ISO8601: ${birthDate.toIso8601String()}');
    
    final r = await _dio.post('/api/profiles', data: requestData);
    
    print('📥 Profile create response: ${r.data}');
    print('📥 Response keys: ${(r.data as Map<String, dynamic>).keys.toList()}');
    
    final profile = ProfileCardDto.fromJson(r.data as Map<String, dynamic>);
    print('📥 Parsed profile birthDate: ${profile.birthDate}');
    print('📥 Parsed profile gender: ${profile.gender}');
    
    return profile;
  }

  Future<void> delete(int profileId) async {
    await _dio.delete('/api/profiles/$profileId');
  }

  Future<ProfileCardDto> getProfileDetails(int profileId) async {
    final r = await _dio.get('/api/profiles/$profileId');
    
    print('📥 Profile details response for ID $profileId: ${r.data}');
    print('📥 Response keys: ${(r.data as Map<String, dynamic>).keys.toList()}');
    
    final profile = ProfileCardDto.fromJson(r.data as Map<String, dynamic>);
    print('📥 Parsed profile details - birthDate: ${profile.birthDate}, gender: ${profile.gender}');
    
    return profile;
  }
}
