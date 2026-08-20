import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'theme/clay_theme.dart';

/// Gambar dari endpoint `/files/*` API.
///
/// `Image.network` biasa TIDAK bisa dipakai untuk berkas ini: endpoint-nya
/// berotorisasi, sedangkan `Image.network` tidak menyertakan token akses.
/// Hasilnya 401 yang tampil sebagai gambar rusak — dan itu terlihat seperti
/// bug jaringan, bukan seperti masalah izin, sehingga sulit ditelusuri.
///
/// Widget ini membaca token dari secure storage lalu meneruskannya sebagai
/// header. `NetworkImage` menyamakan cache berdasarkan URL, jadi header yang
/// menyusul belakangan tidak membuat gambar diunduh ulang tiap build.
class AuthedImage extends ConsumerWidget {
  const AuthedImage(
    this.url, {
    super.key,
    this.width = double.infinity,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.watch(storageProvider).accessToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder(const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ));
        }

        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return _placeholder(const Icon(Icons.lock_outline,
              color: ClayTheme.textMuted));
        }

        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          headers: {'Authorization': 'Bearer $token'},
          errorBuilder: (_, _, _) => _placeholder(const Icon(
            Icons.broken_image_outlined,
            color: ClayTheme.textMuted,
          )),
        );
      },
    );
  }

  Widget _placeholder(Widget child) => Container(
        width: width,
        height: height ?? 140,
        color: ClayTheme.background,
        child: child,
      );
}
