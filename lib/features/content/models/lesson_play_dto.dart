// lib/features/content/models/lesson_play_dto.dart
import 'dart:convert';

class LessonPlayDto {
  final int id;
  final String title;
  final String? hint;
  final String lessonType; // păstrăm string, nu forțăm enum aici
  final int position;
  final List<ScreenDto> screens;

  LessonPlayDto({
    required this.id,
    required this.title,
    this.hint,
    required this.lessonType,
    required this.position,
    required this.screens,
  });

  factory LessonPlayDto.fromJson(Map<String, dynamic> j) => LessonPlayDto(
    id: j['id'],
    title: j['title'] ?? '',
    hint: j['hint'],
    lessonType: j['lessonType'] ?? '',
    position: j['position'] ?? 0,
    screens: (j['screens'] as List? ?? [])
        .map((e) => ScreenDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ScreenDto {
  final int id;
  final ScreenType type;
  final Map<String, dynamic> payload; // payloadJson decodat
  final int position;

  ScreenDto({
    required this.id,
    required this.type,
    required this.payload,
    required this.position,
  });

  factory ScreenDto.fromJson(Map<String, dynamic> j) {
    final raw = j['payloadJson'];
    // payloadJson e string -> decodăm
    final Map<String, dynamic> payload = switch (raw) {
      null => <String, dynamic>{},
      Map<String, dynamic> m => m, // just in case server schimbă
      _ => (jsonDecode(raw.toString()) as Map).cast<String, dynamic>(),
    };

    return ScreenDto(
      id: j['id'],
      type: ScreenTypeX.parse(j['type'] as String?),
      payload: payload,
      position: j['position'] ?? 0,
    );
  }
}

enum ScreenType { readText, readTextWithSub, imageWordSyllables, missingLetterPairs, imageMissingLetter, imageRevealWord, readParagraph, unknown }

extension ScreenTypeX on ScreenType {
  static ScreenType parse(String? s) {
    switch (s) {
      case 'READ_TEXT':
        return ScreenType.readText;
      case 'READ_TEXT_WITH_SUB':
        return ScreenType.readTextWithSub;
      case 'IMAGE_WORD_SYLLABLES':
        return ScreenType.imageWordSyllables;
      case 'MISSING_LETTER_PAIRS':
        return ScreenType.missingLetterPairs;
      case 'IMAGE_MISSING_LETTER':
        return ScreenType.imageMissingLetter;
      case 'IMAGE_REVEAL_WORD':
        return ScreenType.imageRevealWord;
      case 'READ_PARAGRAPH':
        return ScreenType.readParagraph;
      default:
        return ScreenType.unknown; // Fallback – nu blocăm UI
    }
  }
}
