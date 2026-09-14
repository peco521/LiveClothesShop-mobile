import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstracción del almacenamiento de la credencial de sesión.
/// En producción usa almacenamiento seguro del SO; en tests, memoria.
abstract class CredentialStore {
  Future<String?> read();
  Future<void> write(String credential);
  Future<void> delete();
}

class SecureCredentialStore implements CredentialStore {
  final FlutterSecureStorage _storage;
  final String key;

  SecureCredentialStore({FlutterSecureStorage? storage, required this.key})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String credential) => _storage.write(key: key, value: credential);

  @override
  Future<void> delete() => _storage.delete(key: key);
}

class MemoryCredentialStore implements CredentialStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String credential) async => _value = credential;

  @override
  Future<void> delete() async => _value = null;
}
