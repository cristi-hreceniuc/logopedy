class LicenseKeyDTO {
  final int id;
  final String keyUuid;
  final String? profileName;
  final int? profileId;
  final bool isActive;
  final DateTime? activatedAt;
  final DateTime createdAt;

  LicenseKeyDTO({
    required this.id,
    required this.keyUuid,
    this.profileName,
    this.profileId,
    required this.isActive,
    this.activatedAt,
    required this.createdAt,
  });

  factory LicenseKeyDTO.fromJson(Map<String, dynamic> json) {
    return LicenseKeyDTO(
      id: json['id'] as int,
      keyUuid: json['keyUuid'] as String,
      profileName: json['profileName'] as String?,
      profileId: json['profileId'] as int?,
      isActive: json['isActive'] as bool,
      activatedAt: json['activatedAt'] != null 
          ? DateTime.parse(json['activatedAt'] as String) 
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isAvailable => profileId == null && isActive;
  bool get isUsed => profileId != null;
}

