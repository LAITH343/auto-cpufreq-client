import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Persists remote login passwords in OS-encrypted storage (Android Keystore /
/// Keychain), keyed by device host:port. Used only for devices the user chose
/// to stay signed in to; enables silent auto-login on the next launch.
class CredentialStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _key(Device d) => 'pw:${d.host}:${d.port}';

  static Future<void> save(Device d, String password) =>
      _storage.write(key: _key(d), value: password);

  static Future<String?> read(Device d) => _storage.read(key: _key(d));

  static Future<void> delete(Device d) => _storage.delete(key: _key(d));
}
