class KidLoginResponse {
  final String accessToken;
  final int accessExpiresIn;
  final String refreshToken;
  final int refreshExpiresIn;
  final int profileId;
  final String profileName;
  final bool isPremium;

  KidLoginResponse({
    required this.accessToken,
    required this.accessExpiresIn,
    required this.refreshToken,
    required this.refreshExpiresIn,
    required this.profileId,
    required this.profileName,
    required this.isPremium,
  });

  factory KidLoginResponse.fromJson(Map<String, dynamic> json) {
    return KidLoginResponse(
      accessToken: json['accessToken'] as String,
      accessExpiresIn: json['accessExpiresIn'] as int,
      refreshToken: json['refreshToken'] as String,
      refreshExpiresIn: json['refreshExpiresIn'] as int,
      profileId: json['profileId'] as int,
      profileName: json['profileName'] as String,
      isPremium: json['isPremium'] as bool,
    );
  }
}

