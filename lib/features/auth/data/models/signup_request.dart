class SignupRequest {
  final String email, password, firstName, lastName, gender;
  final String? userRole;
  
  const SignupRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.userRole,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    if (userRole != null) 'userRole': userRole,
  };
}
