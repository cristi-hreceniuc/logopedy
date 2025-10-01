import 'dart:convert';
import 'enums.dart';

class ModuleDto {
  final int id;
  final String title;
  final String? introText;
  final int position;
  final bool isPremium;

  ModuleDto({
    required this.id,
    required this.title,
    this.introText,
    required this.position,
    required this.isPremium,
  });

  factory ModuleDto.fromJson(Map<String, dynamic> j) => ModuleDto(
    id: j['id'],
    title: j['title'],
    introText: j['introText'],
    position: j['position'],
    isPremium: j['isPremium'] ?? false,
  );
}

// --- LECȚIE (lite) fără status ---
class LessonLiteDto {
  final int id;
  final String title;
  final LessonType lessonType;
  final int position;

  LessonLiteDto({
    required this.id,
    required this.title,
    required this.lessonType,
    required this.position,
  });

  factory LessonLiteDto.fromJson(Map<String, dynamic> j) => LessonLiteDto(
    id: j['id'],
    title: j['title'],
    lessonType: lessonTypeFrom(j['lessonType']),
    position: j['position'],
  );
}

// --- LECȚIE (lite) CU STATUS (LOCKED/AVAILABLE/DONE) ---
class LessonLiteWithStatus extends LessonLiteDto {
  final String status;

  LessonLiteWithStatus({
    required int id,
    required String title,
    required LessonType lessonType,
    required int position,
    required this.status,
  }) : super(id: id, title: title, lessonType: lessonType, position: position);

  factory LessonLiteWithStatus.fromJson(Map<String, dynamic> j) =>
      LessonLiteWithStatus(
        id: j['id'],
        title: j['title'],
        lessonType: lessonTypeFrom(j['lessonType']),
        position: j['position'],
        status: (j['status'] ?? 'AVAILABLE') as String,
      );
}

// --- SUBMODULE: folosește acum LessonLiteWithStatus ---
class SubmoduleDto {
  final int id;
  final String title;
  final String? introText;
  final int position;
  final List<LessonLiteWithStatus> lessons;

  SubmoduleDto({
    required this.id,
    required this.title,
    this.introText,
    required this.position,
    required this.lessons,
  });

  factory SubmoduleDto.fromJson(Map<String, dynamic> j) => SubmoduleDto(
    id: j['id'],
    title: j['title'],
    introText: j['introText'],
    position: j['position'],
    lessons: (j['lessons'] as List? ?? [])
        .map((e) => LessonLiteWithStatus.fromJson(
        e as Map<String, dynamic>))
        .toList(),
  );
}

// --- SCREEN + LESSON (play) rămân neschimbate ---
class ScreenDto {
  final int id;
  final ScreenType screenType;
  final Map<String, dynamic> payload;
  final int position;

  ScreenDto({
    required this.id,
    required this.screenType,
    required this.payload,
    required this.position,
  });

  factory ScreenDto.fromJson(Map<String, dynamic> j) {
    // backend poate trimite 'type' în loc de 'screenType'
    final typeRaw = j['screenType'] ?? j['type'];

    // backend poate trimite 'payload' (Map) SAU 'payloadJson' (String JSON)
    final rawPayload = j['payload'] ?? j['payloadJson'];
    Map<String, dynamic> payloadMap;
    if (rawPayload is String) {
      payloadMap = _safeDecode(rawPayload);
    } else if (rawPayload is Map) {
      payloadMap = Map<String, dynamic>.from(rawPayload as Map);
    } else {
      payloadMap = <String, dynamic>{};
    }

    return ScreenDto(
      id: j['id'] as int,
      screenType: screenTypeFrom(typeRaw),
      payload: payloadMap,
      position: j['position'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> _safeDecode(String s) {
    try {
      return Map<String, dynamic>.from(jsonDecode(s));
    } catch (_) {
      return {};
    }
  }
}

class LessonDto {
  final int id;
  final String title;
  final String? hint;
  final LessonType lessonType;
  final int position;
  final List<ScreenDto> screens;

  LessonDto({
    required this.id,
    required this.title,
    this.hint,
    required this.lessonType,
    required this.position,
    required this.screens,
  });

  factory LessonDto.fromJson(Map<String, dynamic> j) => LessonDto(
    id: j['id'],
    title: j['title'],
    hint: j['hint'],
    lessonType: lessonTypeFrom(j['lessonType']),
    position: j['position'],
    screens: (j['screens'] as List? ?? [])
        .map((e) => ScreenDto.fromJson(e))
        .toList(),
  );
}

class ProgressDto {
  final int moduleId, submoduleId, lessonId, screenIndex;
  final String status; // IN_PROGRESS / DONE

  ProgressDto({
    required this.moduleId,
    required this.submoduleId,
    required this.lessonId,
    required this.screenIndex,
    required this.status,
  });

  factory ProgressDto.fromJson(Map<String, dynamic> j) => ProgressDto(
    moduleId: j['moduleId'],
    submoduleId: j['submoduleId'],
    lessonId: j['lessonId'],
    screenIndex: j['screenIndex'],
    status: j['status'],
  );
}

class AdvanceResp {
  final int moduleId, submoduleId, lessonId, screenIndex;
  final bool endOfLesson, endOfSubmodule, endOfModule;

  AdvanceResp({
    required this.moduleId,
    required this.submoduleId,
    required this.lessonId,
    required this.screenIndex,
    required this.endOfLesson,
    required this.endOfSubmodule,
    required this.endOfModule,
  });

  factory AdvanceResp.fromJson(Map<String, dynamic> j) => AdvanceResp(
    moduleId: j['next']?['moduleId'] ??
        j['moduleId'] ??
        j['nextModuleId'] ??
        0,
    submoduleId: j['next']?['submoduleId'] ?? j['nextSubmoduleId'] ?? 0,
    lessonId: j['next']?['lessonId'] ?? j['nextLessonId'] ?? 0,
    screenIndex: j['next']?['screenIndex'] ?? 0,
    endOfLesson: j['next']?['endOfLesson'] ?? false,
    endOfSubmodule: j['next']?['endOfSubmodule'] ?? false,
    endOfModule: j['next']?['endOfModule'] ?? false,
  );
}