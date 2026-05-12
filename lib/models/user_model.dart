class User {
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String createdAt;

  User({
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  String get firstLetter => firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
  String get fullName => '$firstName $lastName';
}

class AuthResponse {
  final bool success;
  final String message;
  final String? accessToken;
  final User? user;

  AuthResponse({
    required this.success,
    required this.message,
    this.accessToken,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      accessToken: json['access_token'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}
