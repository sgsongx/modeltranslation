import 'package:modeltranslation/core/domain/gateways/secret_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsSecretVault implements SecretVault {
  static const String _prefix = 'vault.secret.v1.';

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', value);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$key');
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }
}
