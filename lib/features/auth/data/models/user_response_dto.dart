class UserResponseDto {
  final String id;
  final String? firstName;
  final String? lastName;
  final String email;
  final String? password; // Usually not returned, but keeping for compatibility
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? gender;
  final String? role;
  final String? status;
  final bool isPremium;
  final String? profileImageUrl;

  UserResponseDto({
    required this.id,
    this.firstName,
    this.lastName,
    required this.email,
    this.password,
    this.createdAt,
    this.updatedAt,
    this.gender,
    this.role,
    this.status,
    required this.isPremium,
    this.profileImageUrl,
  });

  factory UserResponseDto.fromJson(Map<String, dynamic> json) {
    return UserResponseDto(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      gender: json['gender']?.toString(),
      role: json['role']?.toString(),
      status: json['status']?.toString(),
      isPremium: json['isPremium'] == true || json['isPremium'] == 'true',
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'gender': gender,
      'role': role,
      'status': status,
      'isPremium': isPremium,
      'profileImageUrl': profileImageUrl,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is String) {
        return DateTime.parse(value).toLocal();
      } else if (value is int) {
        // Unix timestamp in milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      } else if (value is List && value.length >= 6) {
        // LocalDateTime format from Java: [year, month, day, hour, minute, second]
        return DateTime(
          value[0] as int,
          value[1] as int,
          value[2] as int,
          value.length > 3 ? (value[3] as int) : 0,
          value.length > 4 ? (value[4] as int) : 0,
          value.length > 5 ? (value[5] as int) : 0,
        );
      }
    } catch (e) {
      // Return null if parsing fails
    }
    return null;
  }
}

