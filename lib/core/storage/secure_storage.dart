import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Secure storage wrapper for sensitive data
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'privacy_vpn_secure_prefs',
      preferencesKeyPrefix: 'privacy_vpn_',
    ),
    iOptions: IOSOptions(
      groupId: 'group.com.privacyvpn.privacy_vpn_controller',
      accountName: 'privacy_vpn_keychain',
    ),
  );

  final Logger _logger = Logger();

  /// Store encrypted string value
  Future<void> store(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      _logger.d('Stored value for key: $key');
    } catch (e) {
      _logger.e('Failed to store value for key $key: $e');
      rethrow;
    }
  }

  /// Retrieve encrypted string value
  Future<String?> retrieve(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      _logger.d('Retrieved value for key: $key');
      return value;
    } catch (e) {
      _logger.e('Failed to retrieve value for key $key: $e');
      return null;
    }
  }

  /// Store JSON object
  Future<void> storeJson(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      await store(key, jsonString);
    } catch (e) {
      _logger.e('Failed to store JSON for key $key: $e');
      rethrow;
    }
  }

  /// Retrieve JSON object
  Future<Map<String, dynamic>?> retrieveJson(String key) async {
    try {
      final jsonString = await retrieve(key);
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.e('Failed to retrieve JSON for key $key: $e');
      return null;
    }
  }

  /// Delete stored value
  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
      _logger.d('Deleted value for key: $key');
    } catch (e) {
      _logger.e('Failed to delete value for key $key: $e');
      rethrow;
    }
  }

  /// Delete all stored values
  Future<void> deleteAll() async {
    try {
      await _secureStorage.deleteAll();
      _logger.i('Deleted all stored values');
    } catch (e) {
      _logger.e('Failed to delete all values: $e');
      rethrow;
    }
  }

  /// Check if key exists
  Future<bool> containsKey(String key) async {
    try {
      final keys = await _secureStorage.readAll();
      return keys.containsKey(key);
    } catch (e) {
      _logger.e('Failed to check if key $key exists: $e');
      return false;
    }
  }
}