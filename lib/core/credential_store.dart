import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstracción del almacenamiento de la credencial de sesión.
/// En producción usa almacenamiento seguro del SO; en tests, memoria.
abstract class CredentialStore {
  Future<String?> read();
  Future<void> write(String credential);
  Future<void> delete();
  Future<String?> readSessionSnapshot();
  Future<void> writeSessionSnapshot(String snapshot);
  Future<void> deleteSessionSnapshot();
}

class SecureCredentialStore implements CredentialStore {
  final FlutterSecureStorage _storage;
  final String key;

  SecureCredentialStore({FlutterSecureStorage? storage, required this.key})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: key);

  String get _snapshotKey => '${key}_session_snapshot';

  @override
  Future<void> write(String credential) => _storage.write(key: key, value: credential);

  @override
  Future<void> delete() => _storage.delete(key: key);

  @override
  Future<String?> readSessionSnapshot() => _storage.read(key: _snapshotKey);

  @override
  Future<void> writeSessionSnapshot(String snapshot) => _storage.write(key: _snapshotKey, value: snapshot);

  @override
  Future<void> deleteSessionSnapshot() => _storage.delete(key: _snapshotKey);
}

class MemoryCredentialStore implements CredentialStore {
  String? _value;
  String? _sessionSnapshot;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String credential) async => _value = credential;

  @override
  Future<void> delete() async => _value = null;

  @override
  Future<String?> readSessionSnapshot() async => _sessionSnapshot;

  @override
  Future<void> writeSessionSnapshot(String snapshot) async => _sessionSnapshot = snapshot;

  @override
  Future<void> deleteSessionSnapshot() async => _sessionSnapshot = null;
}
