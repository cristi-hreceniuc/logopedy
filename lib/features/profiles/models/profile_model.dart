// lib/features/profiles/models/profile_models.dart
class ProfileCardDto {
  final int id;
  final String name;
  final String? avatarUri;
  final bool premium;
  final int progressPercent;
  final int completedLessons;
  final int totalLessons;
  final DateTime? birthDate;
  final String? gender;
  final int? age;

  ProfileCardDto({
    required this.id,
    required this.name,
    this.avatarUri,
    required this.premium,
    required this.progressPercent,
    required this.completedLessons,
    required this.totalLessons,
    this.birthDate,
    this.gender,
    this.age,
  });

  factory ProfileCardDto.fromJson(Map<String, dynamic> j) {
    DateTime? birthDate;
    if (j['birthDate'] != null) {
      if (j['birthDate'] is String) {
        birthDate = DateTime.tryParse(j['birthDate']);
      } else if (j['birthDate'] is int) {
        birthDate = DateTime.fromMillisecondsSinceEpoch(j['birthDate']);
      }
    }
    
    int? age;
    if (birthDate != null) {
      final today = DateTime.now();
      age = today.year - birthDate.year;
      if (today.month < birthDate.month || 
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
    } else if (j['age'] != null) {
      age = j['age'] is int ? j['age'] : int.tryParse(j['age'].toString());
    }

    return ProfileCardDto(
      id: j['id'],
      name: j['name'],
      avatarUri: j['avatarUri'] ?? j['avatarUrl'],
      premium: j['premium'] ?? false,
      progressPercent: j['progressPercent'] ?? 0,
      completedLessons: (j['completedLessons'] ?? 0) as int,
      totalLessons: (j['totalLessons'] ?? 0) as int,
      birthDate: birthDate,
      gender: j['gender']?.toString() ?? j['sex']?.toString(),
      age: age,
    );
  }
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
