import 'package:flutter/material.dart';

/// Palet dan tema **claymorphism** untuk Jargon GO.
///
/// Claymorphism = permukaan yang tampak seperti tanah liat lunak: sudut sangat
/// membulat, warna latar dan kartu nyaris sama, lalu bentuknya muncul dari
/// SEPASANG bayangan — gelap di kanan-bawah dan terang di kiri-atas. Tidak ada
/// garis tepi; kedalamanlah yang memisahkan elemen.
///
/// Konsekuensi yang perlu dijaga di seluruh aplikasi:
///
/// * **Kontras teks tidak boleh ikut melunak.** Latar lembut menggoda untuk
///   memakai teks abu-abu muda, dan hasilnya tidak terbaca di layar ponsel
///   murah di bawah sinar matahari. Warna teks di sini sengaja tetap pekat.
/// * **Bayangan bukan hiasan, melainkan penanda status.** Elemen yang bisa
///   ditekan timbul (bayangan keluar); elemen yang sedang aktif atau berupa
///   isian tenggelam (bayangan ke dalam). Bila keduanya dipakai sembarangan,
///   pengguna kehilangan satu-satunya petunjuk mana yang bisa disentuh.
class ClayTheme {
  const ClayTheme._();

  // ---------------------------------------------------------------
  // Palet
  // ---------------------------------------------------------------

  /// Latar utama — sedikit keunguan supaya bayangan putih terlihat.
  /// Latar putih murni membuat highlight kiri-atas hilang sama sekali.
  static const Color background = Color(0xFFEFF1FA);

  /// Permukaan kartu. Sengaja hanya sedikit lebih terang dari [background]:
  /// perbedaan warna yang besar akan membuat kartu tampak "ditempel", bukan
  /// "dibentuk dari" latar.
  static const Color surface = Color(0xFFF4F6FD);

  static const Color primary = Color(0xFF6C5CE7);
  static const Color primarySoft = Color(0xFFE7E3FF);
  static const Color secondary = Color(0xFF00B8A9);

  static const Color success = Color(0xFF2FBF71);
  static const Color successSoft = Color(0xFFDCF6E8);
  static const Color warning = Color(0xFFF5A524);
  static const Color warningSoft = Color(0xFFFDEFD8);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFBE3E4);
  static const Color info = Color(0xFF3E8FF5);
  static const Color infoSoft = Color(0xFFDFEBFE);

  static const Color textStrong = Color(0xFF232640);
  static const Color textBody = Color(0xFF4A4E69);
  static const Color textMuted = Color(0xFF878BA8);

  /// Bayangan gelap: arah cahaya diasumsikan dari kiri-atas.
  static const Color shadowDark = Color(0x2E9AA5C8);

  /// Bayangan terang. Nyaris putih penuh — inilah yang memberi kesan
  /// permukaan lunak yang "menggembung".
  static const Color shadowLight = Color(0xF2FFFFFF);

  // ---------------------------------------------------------------
  // Ukuran
  // ---------------------------------------------------------------

  /// Radius besar adalah ciri claymorphism. Nilai di bawah ~20 membuat bentuk
  /// terlihat seperti kartu biasa dengan bayangan aneh.
  static const double radius = 26;
  static const double radiusSmall = 18;
  static const double radiusPill = 999;

  /// Bayangan "timbul" untuk elemen yang bisa ditekan.
  static List<BoxShadow> raised({double depth = 1}) => [
        BoxShadow(
          color: shadowDark,
          offset: Offset(6 * depth, 7 * depth),
          blurRadius: 16 * depth,
        ),
        BoxShadow(
          color: shadowLight,
          offset: Offset(-5 * depth, -5 * depth),
          blurRadius: 14 * depth,
        ),
      ];

  /// Bayangan lebih rendah untuk elemen yang sedang ditekan.
  static List<BoxShadow> pressed() => [
        BoxShadow(
          color: shadowDark,
          offset: const Offset(2, 2),
          blurRadius: 6,
        ),
        const BoxShadow(
          color: shadowLight,
          offset: Offset(-1, -1),
          blurRadius: 4,
        ),
      ];

  // ---------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------

  static ThemeData build() {
    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textStrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,

      // Semua elevasi Material dimatikan: kedalaman pada claymorphism datang
      // dari bayangan ganda yang digambar sendiri, bukan dari elevation.
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textStrong),
        titleTextStyle: TextStyle(
          color: textStrong,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textStrong,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // Isian teks digambar "tenggelam" — lihat ClayField. Dekorasi bawaan
      // dibuat transparan agar tidak menimpa bentuk itu.
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: textMuted, fontSize: 14),
      ),

      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textStrong,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(
          color: textStrong,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: textBody, fontSize: 14, height: 1.45),
        bodySmall: TextStyle(color: textMuted, fontSize: 12.5, height: 1.4),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0x1A9AA5C8),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0x229AA5C8),
      ),
    );
  }

  /// Warna aksen untuk status absensi.
  static Color statusColor(String status) => switch (status) {
        'hadir' => success,
        'terlambat' => warning,
        'izin' || 'dispensasi' => info,
        'sakit' => secondary,
        'alfa' => danger,
        _ => textMuted,
      };

  static Color statusSoft(String status) => switch (status) {
        'hadir' => successSoft,
        'terlambat' => warningSoft,
        'izin' || 'dispensasi' => infoSoft,
        'sakit' => const Color(0xFFD9F6F3),
        'alfa' => dangerSoft,
        _ => const Color(0xFFE8EAF2),
      };

  static String statusLabel(String status) => switch (status) {
        'hadir' => 'Hadir',
        'terlambat' => 'Terlambat',
        'izin' => 'Izin',
        'sakit' => 'Sakit',
        'alfa' => 'Tanpa Keterangan',
        'dispensasi' => 'Dispensasi',
        'belum_absen' => 'Belum Absen',
        _ => status,
      };

  /// Warna untuk tingkat keparahan pengaduan.
  static Color severityColor(String severity) => switch (severity) {
        'darurat' => danger,
        'tinggi' => const Color(0xFFEE6B2F),
        'sedang' => warning,
        _ => info,
      };

  static String severityLabel(String severity) => switch (severity) {
        'darurat' => 'Darurat',
        'tinggi' => 'Tinggi',
        'sedang' => 'Sedang',
        _ => 'Rendah',
      };
}
