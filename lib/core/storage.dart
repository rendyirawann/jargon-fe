import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal.
///
/// Dibagi dua dengan sengaja:
///
/// * **Kredensial** (device token, HMAC secret, JWT) masuk ke
///   [FlutterSecureStorage] — Keystore di Android, Keychain di iOS. Tablet
///   kios dipasang di ruang publik; token yang tersimpan sebagai plaintext
///   preferences bisa diambil siapa pun yang memegang perangkat sebentar.
/// * **Konfigurasi non-rahasia** (identitas sekolah, mode perangkat, versi
///   roster) masuk ke SharedPreferences karena sering dibaca saat membangun
///   UI dan tidak perlu biaya dekripsi.
class Storage {
  Storage._(this._prefs);

  // Pada versi flutter_secure_storage saat ini, penyimpanan terenkripsi
  // adalah perilaku bawaan di Android (Keystore) dan iOS (Keychain), sehingga
  // tidak ada opsi tambahan yang perlu diaktifkan.
  static const _secure = FlutterSecureStorage();

  final SharedPreferences _prefs;

  static Future<Storage> open() async =>
      Storage._(await SharedPreferences.getInstance());

  // ---------------- Kredensial perangkat ----------------

  static const _kDeviceToken = 'device_token';
  static const _kHmacSecret = 'hmac_secret';
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  Future<String?> deviceToken() => _secure.read(key: _kDeviceToken);

  Future<String?> hmacSecret() => _secure.read(key: _kHmacSecret);

  Future<String?> accessToken() => _secure.read(key: _kAccessToken);

  Future<String?> refreshToken() => _secure.read(key: _kRefreshToken);

  Future<void> saveDeviceCredentials({
    required String token,
    required String hmacSecret,
  }) async {
    await _secure.write(key: _kDeviceToken, value: token);
    await _secure.write(key: _kHmacSecret, value: hmacSecret);
  }

  Future<void> saveUserTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secure.write(key: _kAccessToken, value: accessToken);
    await _secure.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<void> clearUserTokens() async {
    await _secure.delete(key: _kAccessToken);
    await _secure.delete(key: _kRefreshToken);
  }

  /// Lepas pasangan perangkat. Antrean absensi yang belum terkirim TIDAK
  /// dihapus di sini — data itu milik sekolah dan harus tetap bisa dikirim
  /// setelah perangkat dipasangkan ulang.
  Future<void> clearDevice() async {
    await _secure.delete(key: _kDeviceToken);
    await _secure.delete(key: _kHmacSecret);
    await _prefs.remove(_kDeviceProfile);
    await _prefs.remove(_kRosterVersion);
  }

  // ---------------- Profil perangkat ----------------

  static const _kDeviceProfile = 'device_profile';
  static const _kRosterVersion = 'roster_version';
  static const _kUserProfile = 'user_profile';

  Map<String, dynamic>? deviceProfile() {
    final raw = _prefs.getString(_kDeviceProfile);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDeviceProfile(Map<String, dynamic> profile) =>
      _prefs.setString(_kDeviceProfile, jsonEncode(profile));

  bool get isPaired => _prefs.getString(_kDeviceProfile) != null;

  int rosterVersion() => _prefs.getInt(_kRosterVersion) ?? 0;

  Future<void> saveRosterVersion(int version) =>
      _prefs.setInt(_kRosterVersion, version);

  Map<String, dynamic>? userProfile() {
    final raw = _prefs.getString(_kUserProfile);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserProfile(Map<String, dynamic> profile) =>
      _prefs.setString(_kUserProfile, jsonEncode(profile));

  Future<void> clearUserProfile() => _prefs.remove(_kUserProfile);

  // ---------------- Alamat server ----------------

  static const _kApiBaseUrl = 'api_base_url';

  /// Alamat API pilihan pengguna, atau `null` bila memakai bawaan build.
  ///
  /// Disimpan di preferences, bukan secure storage: ini alamat server, bukan
  /// rahasia — dan ia dibaca saat aplikasi baru mulai, sebelum ada sesi.
  String? apiBaseUrl() => _prefs.getString(_kApiBaseUrl);

  Future<void> saveApiBaseUrl(String url) =>
      _prefs.setString(_kApiBaseUrl, url);

  Future<void> clearApiBaseUrl() => _prefs.remove(_kApiBaseUrl);
}
