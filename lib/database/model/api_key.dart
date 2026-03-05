final class ApiKey {
  final String key;
  final int version;
  final String metadata;
  final bool? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ApiKey({
    required this.key,
    required this.version,
    required this.metadata,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  ApiKey copyWith({
    String? key,
    int? version,
    String? metadata,
    bool? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiKey(
      key: key ?? this.key,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      key: json['key'] as String,
      version: json['version'] as int,
      metadata: json['metadata'] as String,
      status: json['status'] as bool?,
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'version': version,
      'metadata': metadata,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ApiKey &&
        other.key == key &&
        other.version == version &&
        other.metadata == metadata;
  }

  @override
  int get hashCode => Object.hash(key, version, metadata);

  @override
  String toString() => 'ApiKey(key: $key, version: $version)';
}

DateTime? _readDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}
