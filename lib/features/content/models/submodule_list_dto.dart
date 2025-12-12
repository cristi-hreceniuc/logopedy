import 'lesson_list_item_dto.dart';
import 'part_dto.dart';

class SubmoduleListDto {
  final int id;
  final String title;
  final String? introText;
  final int position;
  final List<PartListItemDto> parts;
  
  /// Deprecated: kept for backward compatibility
  @Deprecated('Use parts instead')
  final List<LessonListItemDto>? lessons;

  const SubmoduleListDto({
    required this.id,
    required this.title,
    this.introText,
    required this.position,
    required this.parts,
    this.lessons,
  });

  factory SubmoduleListDto.fromJson(Map<String, dynamic> j) => SubmoduleListDto(
    id: j['id'] as int,
    title: (j['title'] ?? '') as String,
    introText: j['introText'] as String?,
    position: (j['position'] ?? 0) as int,
    parts: (j['parts'] as List? ?? const [])
        .map((e) => PartListItemDto.fromJson(e as Map<String, dynamic>))
        .toList(),
    lessons: j['lessons'] != null
        ? (j['lessons'] as List)
            .map((e) => LessonListItemDto.fromJson(e as Map<String, dynamic>))
            .toList()
        : null,
  );
}
