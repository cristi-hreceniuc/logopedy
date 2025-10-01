class LoginResponse {
  final String token;
  final int expiresInMs;
  final String fullName;
  final String email;

  LoginResponse({
    required this.token,
    required this.expiresInMs,
    required this.fullName,
    required this.email,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
    token: j['token'] as String,
    expiresInMs: (j['expiresIn'] as num).toInt(),
    fullName: (j['user']?['fullName'] ?? '') as String,
    email: (j['user']?['email'] ?? '') as String,
  );
}
