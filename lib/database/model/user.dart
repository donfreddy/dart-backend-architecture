import 'package:postgres/postgres.dart';

final class User {
  final String id;
  final String email;
  final String name;
  final String? profilePicUrl;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.profilePicUrl,
    required this.createdAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? profilePicUrl,
    DateTime? createdAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        profilePicUrl: profilePicUrl ?? this.profilePicUrl,
        createdAt: createdAt ?? this.createdAt,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        profilePicUrl: json['profile_pic_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  factory User.fromRow(ResultRow row) => User(
        id: row[0] as String,
        email: row[1] as String,
        name: row[2] as String,
        profilePicUrl: row[3] as String?,
        createdAt: row[4] as DateTime,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        if (profilePicUrl != null) 'profile_pic_url': profilePicUrl,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) => other is User && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'User(id: $id, email: $email)';
}
