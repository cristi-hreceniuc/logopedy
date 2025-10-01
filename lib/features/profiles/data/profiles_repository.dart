// lib/features/profiles/data/profiles_repository.dart
import '../../../core/network/dio_client.dart';
import '../models/profile_model.dart';
import 'profiles_api.dart';

class ProfilesRepository {
  ProfilesRepository(DioClient client): _api = ProfilesApi(client.dio);
  final ProfilesApi _api;

  Future<List<ProfileCardDto>> listProfiles() async =>
      (await _api.listProfiles()).map((e)=>ProfileCardDto.fromJson(e)).toList().cast<ProfileCardDto>();

  Future<ProfileCardDto> createProfile({required String name, String? avatarUri}) async =>
      ProfileCardDto.fromJson(await _api.createProfile(name: name, avatarUri: avatarUri));

  Future<List<LessonProgressDto>> lessonProgress(int profileId) async =>
      (await _api.lessonProgress(profileId)).map((e)=>LessonProgressDto.fromJson(e)).toList().cast<LessonProgressDto>();
}
