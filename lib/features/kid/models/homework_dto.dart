class HomeworkDTO {
  final int id;
  final int profileId;
  final int? moduleId;
  final String? moduleName;
  final int? submoduleId;
  final String? submoduleName;
  final int? partId;
  final String? partName;
  final DateTime assignedAt;
  final DateTime? dueDate;
  final String? notes;
  // Progress tracking
  final int totalLessons;
  final int completedLessons;
  final DateTime? completedAt;
  final DateTime? specialistDoneAt;

  HomeworkDTO({
    required this.id,
    required this.profileId,
    this.moduleId,
    this.moduleName,
    this.submoduleId,
    this.submoduleName,
    this.partId,
    this.partName,
    required this.assignedAt,
    this.dueDate,
    this.notes,
    this.totalLessons = 0,
    this.completedLessons = 0,
    this.completedAt,
    this.specialistDoneAt,
  });

  factory HomeworkDTO.fromJson(Map<String, dynamic> json) {
    return HomeworkDTO(
      id: json['id'] as int,
      profileId: json['profileId'] as int,
      moduleId: json['moduleId'] as int?,
      moduleName: json['moduleName'] as String?,
      submoduleId: json['submoduleId'] as int?,
      submoduleName: json['submoduleName'] as String?,
      partId: json['partId'] as int?,
      partName: json['partName'] as String?,
      assignedAt: DateTime.parse(json['assignedAt'] as String),
      dueDate: json['dueDate'] != null 
          ? DateTime.parse(json['dueDate'] as String) 
          : null,
      notes: json['notes'] as String?,
      totalLessons: json['totalLessons'] as int? ?? 0,
      completedLessons: json['completedLessons'] as int? ?? 0,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt'] as String) 
          : null,
      specialistDoneAt: json['specialistDoneAt'] != null
          ? DateTime.parse(json['specialistDoneAt'] as String)
          : null,
    );
  }

  /// Get the most specific name for this homework
  String get displayName {
    if (partName != null) return partName!;
    if (submoduleName != null) return submoduleName!;
    if (moduleName != null) return moduleName!;
    return 'Temă';
  }

  /// Get the type description
  String get typeDescription {
    if (partId != null) return 'Parte';
    if (submoduleId != null) return 'Submodul';
    if (moduleId != null) return 'Modul';
    return '';
  }

  /// Progress as a percentage (0.0 to 1.0)
  double get progress => totalLessons > 0 ? completedLessons / totalLessons : 0.0;

  /// Whether this homework is marked as complete
  bool get isMarkedComplete => completedAt != null;

  /// Whether this homework was closed by the specialist
  bool get isClosedBySpecialist => specialistDoneAt != null;

  /// Whether all lessons are done
  bool get isAllLessonsDone => totalLessons > 0 && completedLessons >= totalLessons;
}

