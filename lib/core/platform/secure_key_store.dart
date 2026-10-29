import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureKeyStore {
  Future<String?> readApiKey();

  Future<void> writeApiKey(String value);

  Future<void> deleteApiKey();
}

class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _apiKey = 'question_practice.ai_api_key';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readApiKey() => _storage.read(key: _apiKey);

  @override
  Future<void> writeApiKey(String value) =>
      _storage.write(key: _apiKey, value: value);

  @override
  Future<void> deleteApiKey() => _storage.delete(key: _apiKey);
}

class InMemorySecureKeyStore implements SecureKeyStore {
  String? _value;

  @override
  Future<String?> readApiKey() async => _value;

  @override
  Future<void> writeApiKey(String value) async => _value = value;

  @override
  Future<void> deleteApiKey() async => _value = null;
}
