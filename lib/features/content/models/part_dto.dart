import 'lesson_list_item_dto.dart';

/// Lightweight DTO for Part listing (without lessons)
class PartListItemDto {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final int position;
  final int totalLessons;
  final int completedLessons;

  const PartListItemDto({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.position,
    required this.totalLessons,
    required this.completedLessons,
  });

  factory PartListItemDto.fromJson(Map<String, dynamic> j) => PartListItemDto(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        description: j['description'] as String?,
        position: (j['position'] ?? 0) as int,
        totalLessons: (j['totalLessons'] ?? 0) as int,
        completedLessons: (j['completedLessons'] ?? 0) as int,
      );

  /// Calculate progress percentage (0-100)
  int get progressPercentage {
    if (totalLessons == 0) return 0;
    return ((completedLessons / totalLessons) * 100).round();
  }

  /// Check if part is completed
  bool get isCompleted => totalLessons > 0 && completedLessons >= totalLessons;

  /// Check if part is in progress
  bool get isInProgress => completedLessons > 0 && completedLessons < totalLessons;
}

/// Full DTO for Part with lessons
class PartDto {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final int position;
  final List<LessonListItemDto> lessons;
  final int totalLessons;
  final int completedLessons;

  const PartDto({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.position,
    required this.lessons,
    required this.totalLessons,
    required this.completedLessons,
  });

  factory PartDto.fromJson(Map<String, dynamic> j) => PartDto(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        description: j['description'] as String?,
        position: (j['position'] ?? 0) as int,
        lessons: (j['lessons'] as List? ?? const [])
            .map((e) => LessonListItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalLessons: (j['totalLessons'] ?? 0) as int,
        completedLessons: (j['completedLessons'] ?? 0) as int,
      );

  /// Calculate progress percentage (0-100)
  int get progressPercentage {
    if (totalLessons == 0) return 0;
    return ((completedLessons / totalLessons) * 100).round();
  }

  /// Check if part is completed
  bool get isCompleted => totalLessons > 0 && completedLessons >= totalLessons;

  /// Check if part is in progress
  bool get isInProgress => completedLessons > 0 && completedLessons < totalLessons;
}



