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
/// Palet ini **GELAP** — biru malam. Dua hal berubah dibanding versi terang,
/// dan keduanya bukan sekadar menukar angka warna:
///
/// * **Bayangan terang harus sangat tipis.** Pada latar terang, highlight
///   kiri-atas nyaris putih penuh. Nilai yang sama di atas latar gelap
///   terlihat seperti garis tepi menyala, dan seluruh kesan tanah liat
///   hilang. Sebaliknya bayangan gelapnya harus lebih PEKAT, karena bayangan
///   tipis di atas latar gelap tidak menghasilkan kedalaman apa pun.
/// * **Pasangan "soft" jadi lebih gelap, bukan lebih muda.** `primarySoft`
///   dan kawan-kawannya dipakai sebagai latar lencana; versi pastel di atas
///   latar gelap membuat teks di dalamnya kehilangan kontras.
///
/// * **Kontras teks tidak boleh ikut melunak.** Latar lembut menggoda untuk
///   memakai teks abu-abu muda, dan hasilnya tidak terbaca di layar ponsel
///   murah di bawah sinar matahari. Di mode gelap godaannya terbalik —
///   abu-abu tua yang "kalem" di atas latar gelap sama-sama tidak terbaca.
///   Warna teks di sini sengaja tetap pekat kontrasnya.
/// * **Bayangan bukan hiasan, melainkan penanda status.** Elemen yang bisa
///   ditekan timbul (bayangan keluar); elemen yang sedang aktif atau berupa
///   isian tenggelam (bayangan ke dalam). Bila keduanya dipakai sembarangan,
///   pengguna kehilangan satu-satunya petunjuk mana yang bisa disentuh.
class ClayTheme {
  const ClayTheme._();

  // ---------------------------------------------------------------
  // Palet
  // ---------------------------------------------------------------

  /// Latar utama — biru malam. Bukan hitam netral: bayangan terang pada
  /// claymorphism gelap adalah biru yang lebih muda, dan di atas latar
  /// hitam murni bayangan itu terlihat seperti kabut kelabu, bukan cahaya.
  static const Color background = Color(0xFF131A2E);

  /// Permukaan kartu. Tetap hanya SEDIKIT lebih terang dari [background] —
  /// aturan yang sama seperti versi terang, dan alasannya juga sama:
  /// selisih warna yang besar membuat kartu tampak ditempel, bukan dibentuk
  /// dari latarnya.
  static const Color surface = Color(0xFF1B2540);

  /// Biru aksen. Pada latar gelap warna utama harus LEBIH terang dari latar,
  /// bukan lebih gelap — biru tua di atas biru malam akan hilang sama
  /// sekali, terutama pada layar ponsel murah di bawah sinar matahari.
  static const Color primary = Color(0xFF4C7DF0);

  /// Pasangan "soft" pada mode gelap adalah versi LEBIH GELAP dan pekat,
  /// bukan lebih muda. Dipakai sebagai latar lencana dan chip.
  static const Color primarySoft = Color(0xFF22315C);
  static const Color secondary = Color(0xFF2DD4BF);

  static const Color success = Color(0xFF34D399);
  static const Color successSoft = Color(0xFF17362F);
  static const Color warning = Color(0xFFFBBF24);
  static const Color warningSoft = Color(0xFF3A2E14);
  static const Color danger = Color(0xFFF87171);
  static const Color dangerSoft = Color(0xFF3B1D22);
  static const Color info = Color(0xFF60A5FA);
  static const Color infoSoft = Color(0xFF16294A);

  /// Kontras teks tetap TIDAK dilunakkan, sama seperti versi terang.
  /// Godaannya di mode gelap justru terbalik: memakai abu-abu tua yang
  /// "kalem" di atas latar gelap, dan hasilnya sama-sama tidak terbaca.
  static const Color textStrong = Color(0xFFE8ECF8);
  static const Color textBody = Color(0xFFB4BCD4);
  static const Color textMuted = Color(0xFF7C87A6);

  /// Latar kotak isian. TERANG walau temanya gelap.
  ///
  /// Ini pengecualian yang disengaja terhadap palet gelap. Isian yang
  /// digambar dengan warna `surface` menyatu dengan kartu di sekelilingnya,
  /// dan pengguna kehilangan satu-satunya petunjuk mana yang bisa diketik.
  /// Kotak terang adalah isyarat yang sudah dikenal semua orang tanpa perlu
  /// dipelajari.
  ///
  /// Konsekuensi yang WAJIB diikuti: teks dan hint di dalam isian memakai
  /// [fieldText] dan [fieldHint], BUKAN `textStrong`/`textMuted`. Memakai
  /// warna teks tema gelap di atas kotak terang menghasilkan teks terang di
  /// atas latar terang — isian yang tampak kosong padahal ada isinya.
  static const Color fieldFill = Color(0xFFF3F5FC);
  static const Color fieldText = Color(0xFF1B2540);
  static const Color fieldHint = Color(0xFF8A93AD);

  /// Bayangan gelap: arah cahaya tetap diasumsikan dari kiri-atas.
  /// Lebih pekat daripada versi terang — pada latar gelap, bayangan tipis
  /// tidak menghasilkan kedalaman apa pun.
  static const Color shadowDark = Color(0x8C060A16);

  /// Bayangan terang. Di sini justru harus SANGAT tipis: putih pekat yang
  /// dipakai versi terang akan terlihat seperti garis tepi menyala, dan
  /// seluruh kesan tanah liat hilang. Yang dipakai biru muda ber-alpha
  /// rendah, sekadar menandai sisi yang menghadap cahaya.
  static const Color shadowLight = Color(0x1F7C93D6);

  // ---------------------------------------------------------------
  // Ukuran
  // ---------------------------------------------------------------

  /// Radius besar adalah ciri claymorphism. Nilai di bawah ~20 membuat bentuk
  /// terlihat seperti kartu biasa dengan bayangan aneh.
  static const double radius = 26;
  static const double radiusSmall = 18;
  static const double radiusPill = 999;

  /// Ukuran ikon baku.
  ///
  /// Dijadikan konstanta, bukan angka yang ditulis ulang di tiap layar,
  /// supaya "ikon jangan besar-besar" tidak pelan-pelan hilang setiap kali
  /// ada layar baru. Ikon besar pada tampilan minimalis membuat setiap
  /// elemen berebut perhatian, dan tidak ada lagi yang menonjol.
  static const double icon = 18;
  static const double iconSmall = 15;

  /// Hanya untuk keadaan kosong / ilustrasi, bukan untuk tombol dan menu.
  static const double iconIllustration = 34;

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
    // ColorScheme.dark, bukan .light dengan warna gelap: banyak widget
    // Material memilih warna turunannya sendiri berdasarkan `brightness`.
    // Memakai .light dengan palet gelap membuat widget yang tidak kita
    // gambar sendiri — menu popup, pemilih tanggal, kursor teks — tetap
    // memakai warna terang dan tampak seperti bug.
    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: textStrong,
      secondary: secondary,
      onSecondary: Color(0xFF06231F),
      error: danger,
      onError: Color(0xFF3B1D22),
      surface: surface,
      onSurface: textStrong,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,

      // Ukuran ikon baku dipasang di tema, bukan diulang per layar.
      iconTheme: const IconThemeData(color: textBody, size: icon),

      // Semua elevasi Material dimatikan: kedalaman pada claymorphism datang
      // dari bayangan ganda yang digambar sendiri, bukan dari elevation.
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textStrong, size: icon),
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
      // Latar snackbar TIDAK boleh memakai `textStrong` seperti pada versi
      // terang: di mode gelap warna itu hampir putih, dan teks putih di
      // atasnya menjadi tidak terbaca sama sekali. Dipakai satu tingkat
      // lebih terang dari `surface` supaya tetap terbaca sebagai lapisan
      // yang mengapung di atas isi halaman.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF283557),
        contentTextStyle: const TextStyle(color: textStrong, fontSize: 13.5),
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
        color: Color(0x1FFFFFFF),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0x1A7C93D6),
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

  /// Latar lencana status. Pada mode gelap nilainya adalah versi PEKAT dari
  /// warna statusnya, bukan versi pastel — pastel di atas latar gelap
  /// membuat teks di dalam lencana kehilangan kontras.
  static Color statusSoft(String status) => switch (status) {
        'hadir' => successSoft,
        'terlambat' => warningSoft,
        'izin' || 'dispensasi' => infoSoft,
        'sakit' => const Color(0xFF10332F),
        'alfa' => dangerSoft,
        _ => const Color(0xFF232D48),
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
        'tinggi' => const Color(0xFFFB923C),
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
