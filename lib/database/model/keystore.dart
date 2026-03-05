import 'package:dart_backend_architecture/database/model/user.dart';

final class Keystore {
  final String? id;
  final User client;
  final String primaryKey;
  final String secondaryKey;
  final bool? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Keystore({
    this.id,
    required this.client,
    required this.primaryKey,
    required this.secondaryKey,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  Keystore copyWith({
    String? id,
    User? client,
    String? primaryKey,
    String? secondaryKey,
    bool? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Keystore(
      id: id ?? this.id,
      client: client ?? this.client,
      primaryKey: primaryKey ?? this.primaryKey,
      secondaryKey: secondaryKey ?? this.secondaryKey,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Keystore.fromJson(Map<String, dynamic> json) {
    return Keystore(
      id: json['id'] as String?,
      client: User.fromJson(json['client'] as Map<String, dynamic>),
      primaryKey: json['primary_key'] as String,
      secondaryKey: json['secondary_key'] as String,
      status: json['status'] as bool?,
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'client': client.toJson(),
      'primary_key': primaryKey,
      'secondary_key': secondaryKey,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Keystore &&
        other.client == client &&
        other.primaryKey == primaryKey &&
        other.secondaryKey == secondaryKey;
  }

  @override
  int get hashCode => Object.hash(client, primaryKey, secondaryKey);

  @override
  String toString() => 'Keystore(client: ${client.id}, primaryKey: $primaryKey)';
}

DateTime? _readDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}
