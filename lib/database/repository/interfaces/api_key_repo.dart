import 'package:dart_backend_architecture/database/model/api_key.dart';

abstract interface class ApiKeyRepo {
  Future<ApiKey?> findByKey(String key);
}
