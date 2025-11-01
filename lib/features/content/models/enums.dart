enum LessonType {
  readText,
  readTextWithSub,
  imageWordSyllables,
  readParagraph,
  missingLetterPairs,
  imageMissingLetter,
  imageRevealWord,
  unknown,
}

LessonType lessonTypeFrom(dynamic v) {
  final s = (v ?? '').toString().toUpperCase();
  switch (s) {
    case 'READ_TEXT': return LessonType.readText;
    case 'READ_TEXT_WITH_SUB': return LessonType.readTextWithSub;
    case 'IMAGE_WORD_SYLLABLES': return LessonType.imageWordSyllables;
    case 'READ_PARAGRAPH': return LessonType.readParagraph;
    case 'MISSING_LETTER_PAIRS': return LessonType.missingLetterPairs;
    case 'IMAGE_MISSING_LETTER': return LessonType.imageMissingLetter;
    case 'IMAGE_REVEAL_WORD': return LessonType.imageRevealWord;
    default: return LessonType.unknown;
  }
}

enum ScreenType {
  readText,
  readTextWithSub,
  imageWordSyllables,
  readParagraph,
  missingLetterPairs,
  imageMissingLetter,
  imageRevealWord,
  unknown,
}

ScreenType screenTypeFrom(dynamic v) {
  final s = (v ?? '').toString().toUpperCase();
  switch (s) {
    case 'READ_TEXT': return ScreenType.readText;
    case 'READ_TEXT_WITH_SUB': return ScreenType.readTextWithSub;
    case 'IMAGE_WORD_SYLLABLES': return ScreenType.imageWordSyllables;
    case 'READ_PARAGRAPH': return ScreenType.readParagraph;
    case 'MISSING_LETTER_PAIRS': return ScreenType.missingLetterPairs;
    case 'IMAGE_MISSING_LETTER': return ScreenType.imageMissingLetter;
    case 'IMAGE_REVEAL_WORD': return ScreenType.imageRevealWord;
    default: return ScreenType.unknown;
  }
}

extension LessonTypeExtension on LessonType {
  String get romanianDescription {
    switch (this) {
      case LessonType.readText:
        return 'Citește textul afișat';
      case LessonType.readTextWithSub:
        return 'Citește textul și urmează instrucțiunile';
      case LessonType.imageWordSyllables:
        return 'Asociază imaginea cu cuvântul și silabele';
      case LessonType.readParagraph:
        return 'Citește propozițiile cu atenție';
      case LessonType.missingLetterPairs:
        return 'Completează litera lipsă din cuvânt';
      case LessonType.imageMissingLetter:
        return 'Completează litera lipsă după imagine';
      case LessonType.imageRevealWord:
        return 'Dezvăluie cuvântul din imagine';
      case LessonType.unknown:
        return 'Tip de lecție necunoscut';
    }
  }
}
