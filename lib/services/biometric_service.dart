import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  static const _biometricEnabledKey = 'biometric_enabled';
  static final _auth = LocalAuthentication();
  static final _storage = const FlutterSecureStorage();

  static Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to login',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          // biometricOnly: false (default), so all biometrics are allowed
        ),
      );
    } catch (e) {
      debugPrint('Biometric authenticate() error: $e');
      return false;
    }
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled ? 'true' : 'false');
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }
} 