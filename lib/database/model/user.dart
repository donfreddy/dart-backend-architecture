import 'package:postgres/postgres.dart';

final class User {
  final String id;
  final String email;
  final String name;
  final String? passwordHash;
  final String? profilePicUrl;
  final DateTime createdAt;
  final List<String> roles;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.passwordHash,
    this.profilePicUrl,
    required this.createdAt,
    this.roles = const [],
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? passwordHash,
    String? profilePicUrl,
    DateTime? createdAt,
    List<String>? roles,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        passwordHash: passwordHash ?? this.passwordHash,
        profilePicUrl: profilePicUrl ?? this.profilePicUrl,
        createdAt: createdAt ?? this.createdAt,
        roles: roles ?? this.roles,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        passwordHash: json['password_hash'] as String?,
        profilePicUrl: json['profile_pic_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        roles: ((json['roles'] as List?) ?? const []).cast<String>(),
      );

  factory User.fromRow(ResultRow row) {
    final rawRoles = row.length > 6 ? row[6] : null;
    final roles = switch (rawRoles) {
      final List<dynamic> values => values.cast<String>(),
      _ => const <String>[],
    };

    return User(
      id: row[0] as String,
      email: row[1] as String,
      name: row[2] as String,
      profilePicUrl: row[3] as String?,
      createdAt: row[4] as DateTime,
      passwordHash: row.length > 5 ? row[5] as String? : null,
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        if (profilePicUrl != null) 'profile_pic_url': profilePicUrl,
        'created_at': createdAt.toIso8601String(),
        if (roles.isNotEmpty) 'roles': roles,
      };

  @override
  bool operator ==(Object other) => other is User && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'User(id: $id, email: $email)';
}
