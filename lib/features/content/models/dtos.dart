import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      payloadMap = Map<String, dynamic>.from(rawPayload);
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
  final int? nextModuleId, nextSubmoduleId, nextLessonId;
  final bool endOfLesson, endOfSubmodule, endOfModule;

  AdvanceResp({
    required this.moduleId,
    required this.submoduleId,
    required this.lessonId,
    required this.screenIndex,
    this.nextModuleId,
    this.nextSubmoduleId,
    this.nextLessonId,
    required this.endOfLesson,
    required this.endOfSubmodule,
    required this.endOfModule,
  });

  factory AdvanceResp.fromJson(Map<String, dynamic> j) {
    // Debug logging to understand the API response structure
    debugPrint('🔍 AdvanceResp.fromJson received: $j');
    
    // Extract current lesson data
    final currentModuleId = j['moduleId'] ?? 0;
    final currentSubmoduleId = j['submoduleId'] ?? 0;
    final currentLessonId = j['lessonId'] ?? 0;
    final currentScreenIndex = j['screenIndex'] ?? 0;
    
    // Extract next lesson data - check multiple possible structures
    final nextData = j['next'] as Map<String, dynamic>?;
    final nextLessonData = j['nextLesson'] as Map<String, dynamic>?;
    final nextModuleData = j['nextModule'] as Map<String, dynamic>?;
    
    // Try to get next lesson ID from various possible locations
    int? nextLessonId = nextData?['lessonId'] ?? 
                       nextData?['id'] ??
                       nextLessonData?['id'] ??
                       nextLessonData?['lessonId'] ??
                       j['nextLessonId'] ??
                       j['nextId'];
    
    // Try to get next module ID
    int? nextModuleId = nextData?['moduleId'] ?? 
                       nextModuleData?['id'] ??
                       nextModuleData?['moduleId'] ??
                       j['nextModuleId'];
    
    // Try to get next submodule ID
    int? nextSubmoduleId = nextData?['submoduleId'] ?? 
                          j['nextSubmoduleId'];
    
    // Extract flags - check multiple possible locations
    final endOfLesson = nextData?['endOfLesson'] ?? 
                       j['endOfLesson'] ?? 
                       j['isEndOfLesson'] ?? 
                       false;
    final endOfSubmodule = nextData?['endOfSubmodule'] ?? 
                          j['endOfSubmodule'] ?? 
                          j['isEndOfSubmodule'] ?? 
                          false;
    final endOfModule = nextData?['endOfModule'] ?? 
                       j['endOfModule'] ?? 
                       j['isEndOfModule'] ?? 
                       false;
    
    debugPrint('🔍 Parsed data - Current: module=$currentModuleId, submodule=$currentSubmoduleId, lesson=$currentLessonId');
    debugPrint('🔍 Parsed data - Next: module=$nextModuleId, submodule=$nextSubmoduleId, lesson=$nextLessonId');
    debugPrint('🔍 Parsed flags - endOfLesson=$endOfLesson, endOfSubmodule=$endOfSubmodule, endOfModule=$endOfModule');
    
    // Don't infer next lesson ID - trust the backend response
    // If nextLessonId is null, it means there is no next lesson
    
    return AdvanceResp(
      moduleId: currentModuleId,
      submoduleId: currentSubmoduleId,
      lessonId: currentLessonId,
      screenIndex: currentScreenIndex,
      nextModuleId: nextModuleId,
      nextSubmoduleId: nextSubmoduleId,
      nextLessonId: nextLessonId,
      endOfLesson: endOfLesson,
      endOfSubmodule: endOfSubmodule,
      endOfModule: endOfModule,
    );
  }
}