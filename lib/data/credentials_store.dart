import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'xtream_config.dart';

/// Persists the portal and credentials.
///
/// Deliberately not SharedPreferences: on Android that is a plaintext XML file
/// in the app sandbox, readable by anything with filesystem access on a rooted
/// or backed-up device. `flutter_secure_storage` backs onto the Keystore /
/// Keychain instead.
class CredentialsStore {
  CredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kPortal = 'xtream.portal';
  static const _kUsername = 'xtream.username';
  static const _kPassword = 'xtream.password';

  Future<XtreamConfig?> read() async {
    final portal = await _storage.read(key: _kPortal);
    final username = await _storage.read(key: _kUsername);
    final password = await _storage.read(key: _kPassword);

    if (portal == null || username == null || password == null) return null;
    if (portal.isEmpty || username.isEmpty || password.isEmpty) return null;

    return XtreamConfig(
      portalUrl: portal,
      username: username,
      password: password,
    );
  }

  Future<void> write(XtreamConfig config) async {
    await _storage.write(
      key: _kPortal,
      value: config.normalisedPortalUrl,
    );
    await _storage.write(key: _kUsername, value: config.username);
    await _storage.write(key: _kPassword, value: config.password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kPortal);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kPassword);
  }
}
