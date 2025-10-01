class LessonListItemDto {
  final int id;
  final String title;
  final String? hint;
  final String lessonType; // ex: READ_TEXT, IMAGE_WORD_SYLLABLES
  final int position;
  final String status;     // LOCKED / UNLOCKED / DONE

  const LessonListItemDto({
    required this.id,
    required this.title,
    this.hint,
    required this.lessonType,
    required this.position,
    required this.status,
  });

  factory LessonListItemDto.fromJson(Map<String, dynamic> j) => LessonListItemDto(
    id: j['id'] as int,
    title: (j['title'] ?? '') as String,
    hint: j['hint'] as String?,
    lessonType: (j['lessonType'] ?? '') as String,
    position: (j['position'] ?? 0) as int,
    status: (j['status'] ?? 'LOCKED') as String,
  );

  bool get isLocked => status == 'LOCKED';
  bool get canEnter => status == 'UNLOCKED' || status == 'DONE';
}
