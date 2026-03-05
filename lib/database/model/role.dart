enum RoleCode {
  learner('LEARNER'),
  writer('WRITER'),
  editor('EDITOR'),
  admin('ADMIN');

  final String value;
  const RoleCode(this.value);

  static RoleCode? fromValue(String value) {
    for (final code in RoleCode.values) {
      if (code.value == value) return code;
    }
    return null;
  }
}

final class Role {
  final String id;
  final String code;
  final bool? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Role({
    required this.id,
    required this.code,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  Role copyWith({
    String? id,
    String? code,
    bool? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      code: code ?? this.code,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      code: json['code'] as String,
      status: json['status'] as bool?,
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  factory Role.fromRow(List<dynamic> row) {
    return Role(
      id: row[0] as String,
      code: row[1] as String,
      status: row[2] as bool?,
      createdAt: row[3] as DateTime?,
      updatedAt: row[4] as DateTime?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}

DateTime? _readDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}
