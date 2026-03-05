import 'package:dart_backend_architecture/database/model/keystore.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

abstract interface class KeystoreRepo {
  Future<Keystore?> findForKey(User client, String key);
  Future<Keystore?> remove(String id);
  Future<Keystore?> find(User client, String primaryKey, String secondaryKey);
  Future<Keystore> create(User client, String primaryKey, String secondaryKey);
}
