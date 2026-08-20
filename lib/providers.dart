import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/api_config.dart';
import 'core/storage.dart';
import 'data/models.dart';
import 'data/offline_queue.dart';
import 'data/repository.dart';

/// Dependensi yang disiapkan sebelum aplikasi berjalan (lihat main.dart),
/// lalu di-override ke dalam graf provider. Dengan begitu tidak ada layar
/// yang perlu menunggu inisialisasi asinkron.
final storageProvider = Provider<Storage>((_) {
  throw StateError('storageProvider harus di-override di main()');
});

final offlineQueueProvider = Provider<OfflineQueue>((_) {
  throw StateError('offlineQueueProvider harus di-override di main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(storageProvider));
});

final repositoryProvider = Provider<AbsensiRepository>((ref) {
  return AbsensiRepository(
    ref.watch(apiClientProvider),
    ref.watch(storageProvider),
    ref.watch(offlineQueueProvider),
  );
});

/// Alamat server API yang sedang dipakai.
///
/// [ApiConfig] adalah sumber kebenarannya — klien HTTP membacanya langsung
/// pada tiap request. Provider ini hanya cerminnya untuk UI, supaya layar yang
/// menampilkan alamat ikut berubah begitu pengguna menyimpannya, tanpa perlu
/// keluar-masuk halaman.
final apiBaseUrlProvider = StateProvider<String>((ref) => ApiConfig.baseUrl);

/// Profil perangkat kios yang tersimpan lokal. `null` bila belum dipasangkan.
final deviceProfileProvider = StateProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(storageProvider).deviceProfile();
});

/// Profil pengguna yang sedang masuk (guru / kepala sekolah).
final currentUserProvider = StateProvider<UserProfile?>((ref) {
  return ref.watch(repositoryProvider).cachedUser();
});

/// Jumlah absensi yang masih menunggu terkirim.
final pendingCountProvider = StreamProvider<int>((ref) async* {
  final repo = ref.watch(repositoryProvider);
  // Angka ini muncul sebagai lencana di layar kios; interval 5 detik cukup
  // responsif tanpa membebani penyimpanan tablet.
  while (true) {
    yield await repo.pendingCount();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});
