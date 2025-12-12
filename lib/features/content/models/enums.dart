enum LessonType {
  readText,
  readTextWithSub,
  imageWordSyllables,
  readParagraph,
  missingLetterPairs,
  imageMissingLetter,
  imageRevealWord,
  // New types for specialist modules
  instructions,
  imageSelection,
  audioSelection,
  syllableSelection,
  wordSelection,
  findSound,
  findSoundWithImage,
  findMissingLetter,
  findNonIntruder,
  formatWord,
  repeatWord,
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
    // New types
    case 'INSTRUCTIONS': return LessonType.instructions;
    case 'IMAGE_SELECTION': return LessonType.imageSelection;
    case 'AUDIO_SELECTION': return LessonType.audioSelection;
    case 'SYLLABLE_SELECTION': return LessonType.syllableSelection;
    case 'WORD_SELECTION': return LessonType.wordSelection;
    case 'FIND_SOUND': return LessonType.findSound;
    case 'FIND_SOUND_WITH_IMAGE': return LessonType.findSoundWithImage;
    case 'FIND_MISSING_LETTER': return LessonType.findMissingLetter;
    case 'FIND_NON_INTRUDER': return LessonType.findNonIntruder;
    case 'FORMAT_WORD': return LessonType.formatWord;
    case 'REPEAT_WORD': return LessonType.repeatWord;
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
  // New types for specialist modules
  instructions,
  imageSelection,
  audioSelection,
  syllableSelection,
  wordSelection,
  findSound,
  findSoundWithImage,
  findMissingLetter,
  findNonIntruder,
  formatWord,
  repeatWord,
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
    // New types
    case 'INSTRUCTIONS': return ScreenType.instructions;
    case 'IMAGE_SELECTION': return ScreenType.imageSelection;
    case 'AUDIO_SELECTION': return ScreenType.audioSelection;
    case 'SYLLABLE_SELECTION': return ScreenType.syllableSelection;
    case 'WORD_SELECTION': return ScreenType.wordSelection;
    case 'FIND_SOUND': return ScreenType.findSound;
    case 'FIND_SOUND_WITH_IMAGE': return ScreenType.findSoundWithImage;
    case 'FIND_MISSING_LETTER': return ScreenType.findMissingLetter;
    case 'FIND_NON_INTRUDER': return ScreenType.findNonIntruder;
    case 'FORMAT_WORD': return ScreenType.formatWord;
    case 'REPEAT_WORD': return ScreenType.repeatWord;
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
      // New types
      case LessonType.instructions:
        return 'Citește instrucțiunile';
      case LessonType.imageSelection:
        return 'Selectează imaginea corectă';
      case LessonType.audioSelection:
        return 'Selectează sunetul corect';
      case LessonType.syllableSelection:
        return 'Selectează silaba corectă';
      case LessonType.wordSelection:
        return 'Selectează cuvântul corect';
      case LessonType.findSound:
        return 'Găsește sunetul în cuvânt';
      case LessonType.findSoundWithImage:
        return 'Găsește sunetul în cuvânt';
      case LessonType.findMissingLetter:
        return 'Găsește litera lipsă';
      case LessonType.findNonIntruder:
        return 'Găsește elementele care se potrivesc';
      case LessonType.formatWord:
        return 'Formează cuvântul corect';
      case LessonType.repeatWord:
        return 'Repetă cuvântul';
      case LessonType.unknown:
        return 'Tip de lecție necunoscut';
    }
  }
}
