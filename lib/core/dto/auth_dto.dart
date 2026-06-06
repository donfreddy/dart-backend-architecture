import 'package:dart_backend_architecture/core/jwt/jwt_service.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

final class LoginDto {
  final String email;
  final String password;

  const LoginDto({required this.email, required this.password});

  factory LoginDto.fromJson(Map<String, dynamic> json) => LoginDto(
        email: json['email'] as String,
        password: json['password'] as String,
      );
}

final class SignupDto {
  final String name;
  final String email;
  final String password;
  final String? profilePicUrl;

  const SignupDto({
    required this.name,
    required this.email,
    required this.password,
    this.profilePicUrl,
  });

  factory SignupDto.fromJson(Map<String, dynamic> json) => SignupDto(
        name: json['name'] as String,
        email: json['email'] as String,
        password: json['password'] as String,
        profilePicUrl: json['profile_pic_url'] as String?,
      );
}

final class AuthResult {
  final User user;
  final TokenPair tokens;

  const AuthResult({required this.user, required this.tokens});

  Map<String, dynamic> toJson() => {
        'user': {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'roles': user.roles,
          if (user.profilePicUrl != null) 'profile_pic_url': user.profilePicUrl,
        },
        'tokens': tokens.toJson(),
      };
}
