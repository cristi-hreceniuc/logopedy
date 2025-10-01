class UserDto {
  final String id, firstName, lastName, email, gender, userRole, userStatus, username;
  final bool enabled, accountNonExpired, accountNonLocked, credentialsNonExpired;

  UserDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.gender,
    required this.userRole,
    required this.userStatus,
    required this.username,
    required this.enabled,
    required this.accountNonExpired,
    required this.accountNonLocked,
    required this.credentialsNonExpired,
  });

  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
    id: j['id'],
    firstName: j['firstName'],
    lastName: j['lastName'],
    email: j['email'],
    gender: j['gender'] ?? '',
    userRole: j['userRole'] ?? '',
    userStatus: j['userStatus'] ?? '',
    username: j['username'] ?? '',
    enabled: j['enabled'] ?? false,
    accountNonExpired: j['accountNonExpired'] ?? false,
    accountNonLocked: j['accountNonLocked'] ?? false,
    credentialsNonExpired: j['credentialsNonExpired'] ?? false,
  );
}
