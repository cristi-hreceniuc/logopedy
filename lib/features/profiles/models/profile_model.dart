// lib/features/profiles/models/profile_models.dart
class ProfileCardDto {
  final int id;
  final String name;
  final String? avatarUri;
  final bool premium;
  final int progressPercent;
  final int completedLessons;
  final int totalLessons;

  ProfileCardDto({
    required this.id, required this.name, this.avatarUri,
    required this.premium, required this.progressPercent,
    required this.completedLessons, required this.totalLessons,
  });

  factory ProfileCardDto.fromJson(Map<String,dynamic> j) => ProfileCardDto(
    id: j['id'], name: j['name'], avatarUri: j['avatarUri'],
    premium: j['premium'] ?? false,
    progressPercent: j['progressPercent'] ?? 0,
    completedLessons: (j['completedLessons'] ?? 0) as int,
    totalLessons: (j['totalLessons'] ?? 0) as int,
  );
}

class LessonProgressDto {
  final int moduleId; final String moduleTitle;
  final int submoduleId; final String submoduleTitle;
  final int lessonId; final String lessonTitle;
  final String status; // LOCKED/UNLOCKED/DONE

  LessonProgressDto({
    required this.moduleId, required this.moduleTitle,
    required this.submoduleId, required this.submoduleTitle,
    required this.lessonId, required this.lessonTitle,
    required this.status,
  });

  factory LessonProgressDto.fromJson(Map<String,dynamic> j) => LessonProgressDto(
    moduleId: j['moduleId'], moduleTitle: j['moduleTitle'],
    submoduleId: j['submoduleId'], submoduleTitle: j['submoduleTitle'],
    lessonId: j['lessonId'], lessonTitle: j['lessonTitle'],
    status: j['status'],
  );
}
