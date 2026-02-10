import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart';
import 'package:logger/logger.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const _masterKeyAlias = 'privacy_vpn_master_key';
  static const _ivKeyAlias = 'privacy_vpn_iv_key';
  final _logger = Logger();

  late final Encrypter _encrypter;
  late final IV _iv;
  bool _initialized = false;

  /// Initialize the secure storage system
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get or create master encryption key
      String? masterKey = await _storage.read(key: _masterKeyAlias);
      if (masterKey == null) {
        masterKey = _generateSecureKey();
        await _storage.write(key: _masterKeyAlias, value: masterKey);
        _logger.i('Generated new master encryption key');
      }

      // Get or create IV
      String? ivString = await _storage.read(key: _ivKeyAlias);
      if (ivString == null) {
        _iv = IV.fromSecureRandom(16);
        await _storage.write(key: _ivKeyAlias, value: _iv.base64);
        _logger.i('Generated new initialization vector');
      } else {
        _iv = IV.fromBase64(ivString);
      }

      // Initialize encrypter
      final key = Key.fromBase64(masterKey);
      _encrypter = Encrypter(AES(key));
      _initialized = true;
      
      _logger.i('Secure storage initialized successfully');
    } catch (e, stack) {
      _logger.e('Failed to initialize secure storage', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Generate a cryptographically secure key
  String _generateSecureKey() {
    final key = Key.fromSecureRandom(32);
    return key.base64;
  }

  /// Store encrypted data
  Future<void> storeSecure(String key, Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    try {
      final jsonString = jsonEncode(data);
      final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
      await _storage.write(key: key, value: encrypted.base64);
      
      _logger.d('Stored encrypted data for key: ${key.substring(0, 8)}...');
    } catch (e, stack) {
      _logger.e('Failed to store secure data for key: $key', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Retrieve and decrypt data
  Future<Map<String, dynamic>?> retrieveSecure(String key) async {
    await _ensureInitialized();
    
    try {
      final encryptedData = await _storage.read(key: key);
      if (encryptedData == null) {
        return null;
      }
      
      final encrypted = Encrypted.fromBase64(encryptedData);
      final decryptedJson = _encrypter.decrypt(encrypted, iv: _iv);
      final data = jsonDecode(decryptedJson) as Map<String, dynamic>;
      
      return data;
    } catch (e, stack) {
      _logger.e('Failed to retrieve secure data for key: $key', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Store encrypted list of items
  Future<void> storeSecureList(String key, List<Map<String, dynamic>> dataList) async {
    await _ensureInitialized();
    
    try {
      final listData = {'items': dataList, 'count': dataList.length};
      await storeSecure(key, listData);
    } catch (e, stack) {
      _logger.e('Failed to store secure list for key: $key', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Retrieve encrypted list of items
  Future<List<Map<String, dynamic>>> retrieveSecureList(String key) async {
    await _ensureInitialized();
    
    try {
      final data = await retrieveSecure(key);
      if (data == null || !data.containsKey('items')) {
        return [];
      }
      
      final items = (data['items'] as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
      
      return items;
    } catch (e, stack) {
      _logger.e('Failed to retrieve secure list for key: $key', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Delete secure data
  Future<void> deleteSecure(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e, stack) {
      _logger.e('Failed to delete secure data for key: $key', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Clear all secure storage (WARNING: irreversible)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      _initialized = false;
      _logger.w('Cleared all secure storage data');
    } catch (e, stack) {
      _logger.e('Failed to clear secure storage', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}