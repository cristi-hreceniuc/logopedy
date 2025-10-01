import 'lesson_list_item_dto.dart';

class SubmoduleListDto {
  final int id;
  final String title;
  final String? introText;
  final int position;
  final List<LessonListItemDto> lessons;

  const SubmoduleListDto({
    required this.id,
    required this.title,
    this.introText,
    required this.position,
    required this.lessons,
  });

  factory SubmoduleListDto.fromJson(Map<String, dynamic> j) => SubmoduleListDto(
    id: j['id'] as int,
    title: (j['title'] ?? '') as String,
    introText: j['introText'] as String?,
    position: (j['position'] ?? 0) as int,
    lessons: (j['lessons'] as List? ?? const [])
        .map((e) => LessonListItemDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
