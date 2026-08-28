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

  // ---------------------------------------------------------------
  // Mode aktif
  // ---------------------------------------------------------------

  static bool _gelap = true;

  /// `true` bila tema gelap sedang dipakai.
  static bool get gelap => _gelap;

  /// Ganti tema.
  ///
  /// Pemanggil bertanggung jawab membangun ulang pohon widget — warna di
  /// sini DIBACA saat build, bukan didengarkan. Menyetel ini tanpa memicu
  /// rebuild tidak akan mengubah apa pun di layar.
  static void pakai({required bool gelap}) => _gelap = gelap;

  // ---------------------------------------------------------------
  // Palet — getter, bukan `const`
  //
  // Semula seluruhnya `static const`, dan 298 tempat di aplikasi membacanya
  // langsung. Itu bekerja sempurna untuk SATU tema dan mustahil untuk dua:
  // nilai const ditentukan saat kompilasi, jadi tidak ada cara menukarnya
  // saat aplikasi berjalan.
  //
  // Perlu dicatat bahwa ini BUKAN akibat memilih pendekatan getter —
  // `Theme.of(context).x` juga tidak bisa dipakai di dalam `const TextStyle`.
  // Melepas `const` pada widget yang memakai warna tema tidak dapat
  // dihindari oleh pendekatan mana pun.
  //
  // Yang hilang: `const` pada widget-widget itu, sehingga Flutter tidak lagi
  // menyimpan instansnya. Yang didapat: 298 tempat itu tidak perlu diubah.
  // ---------------------------------------------------------------

  static Color get background => _gelap ? _G.background : _T.background;
  static Color get surface => _gelap ? _G.surface : _T.surface;
  static Color get primary => _gelap ? _G.primary : _T.primary;
  static Color get primarySoft => _gelap ? _G.primarySoft : _T.primarySoft;
  static Color get secondary => _gelap ? _G.secondary : _T.secondary;

  static Color get success => _gelap ? _G.success : _T.success;
  static Color get successSoft => _gelap ? _G.successSoft : _T.successSoft;
  static Color get warning => _gelap ? _G.warning : _T.warning;
  static Color get warningSoft => _gelap ? _G.warningSoft : _T.warningSoft;
  static Color get danger => _gelap ? _G.danger : _T.danger;
  static Color get dangerSoft => _gelap ? _G.dangerSoft : _T.dangerSoft;
  static Color get info => _gelap ? _G.info : _T.info;
  static Color get infoSoft => _gelap ? _G.infoSoft : _T.infoSoft;

  static Color get textStrong => _gelap ? _G.textStrong : _T.textStrong;
  static Color get textBody => _gelap ? _G.textBody : _T.textBody;
  static Color get textMuted => _gelap ? _G.textMuted : _T.textMuted;

  /// Latar snackbar netral.
  ///
  /// Di mode gelap TIDAK boleh memakai `textStrong` (hampir putih), karena
  /// teks di atasnya juga terang — pesan galat yang tidak terbaca lebih
  /// buruk daripada tidak ada pesan.
  static Color get snackBg =>
      _gelap ? const Color(0xFF283557) : const Color(0xFF232640);
  static Color get snackText =>
      _gelap ? _G.textStrong : const Color(0xFFF4F6FD);

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

  /// Puncak kilau kerangka pemuatan.
  ///
  /// Harus LEBIH TERANG dari `surface` di tema terang, dan lebih terang juga
  /// di tema gelap — kilau yang lebih gelap dari latarnya terbaca sebagai
  /// bayangan bergerak, bukan cahaya.
  static Color get shimmerHighlight =>
      _gelap ? const Color(0xFF2A3A63) : const Color(0xFFFFFFFF);

  /// Latar sidebar, satu tingkat LEBIH DALAM dari [background].
  ///
  /// ZoomDrawer memiringkan layar utama lalu meletakkannya di atas sidebar.
  /// Bila keduanya sewarna, tidak ada yang menandai mana yang di depan —
  /// dan bayangan saja tidak cukup, terutama pada tema gelap yang seluruh
  /// paletnya sudah gelap.
  static Color get sidebarBg =>
      _gelap ? const Color(0xFF0E1424) : const Color(0xFFE3E7F4);

  /// Latar baris menu di sidebar yang TIDAK aktif.
  static Color get sidebarRow =>
      _gelap ? const Color(0xFF16203A) : const Color(0xFFF1F4FD);

  /// Bayangan gelap: arah cahaya tetap diasumsikan dari kiri-atas.
  static Color get shadowDark => _gelap ? _G.shadowDark : _T.shadowDark;

  /// Bayangan terang — dan inilah yang paling berbeda antara dua tema.
  ///
  /// Pada latar terang ia nyaris putih penuh, dan itulah yang memberi kesan
  /// permukaan menggembung. Nilai yang sama di atas latar gelap terlihat
  /// seperti garis tepi menyala dan seluruh kesan tanah liat hilang, jadi di
  /// mode gelap ia justru biru muda ber-alpha sangat rendah.
  static Color get shadowLight => _gelap ? _G.shadowLight : _T.shadowLight;

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
          offset: Offset(2, 2),
          blurRadius: 6,
        ),
        BoxShadow(
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
    final scheme = (_gelap ? ColorScheme.dark : ColorScheme.light)(
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
      iconTheme: IconThemeData(color: textBody, size: icon),

      // Semua elevasi Material dimatikan: kedalaman pada claymorphism datang
      // dari bayangan ganda yang digambar sendiri, bukan dari elevation.
      appBarTheme: AppBarTheme(
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
      cardTheme: CardThemeData(
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
        backgroundColor: snackBg,
        contentTextStyle: TextStyle(color: textStrong, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // Isian teks digambar "tenggelam" — lihat ClayField. Dekorasi bawaan
      // dibuat transparan agar tidak menimpa bentuk itu.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: textMuted, fontSize: 14),
      ),

      textTheme: TextTheme(
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
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

/// Palet GELAP — biru malam.
class _G {
  const _G._();

  /// Bukan hitam netral: bayangan terang pada claymorphism gelap adalah biru
  /// yang lebih muda, dan di atas hitam murni ia terlihat seperti kabut
  /// kelabu alih-alih cahaya.
  static const Color background = Color(0xFF131A2E);
  static const Color surface = Color(0xFF1B2540);

  /// Pada latar gelap, warna utama harus LEBIH terang dari latarnya.
  static const Color primary = Color(0xFF4C7DF0);

  /// Pasangan "soft" di mode gelap adalah versi PEKAT, bukan pastel.
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

  static const Color textStrong = Color(0xFFE8ECF8);
  static const Color textBody = Color(0xFFB4BCD4);
  static const Color textMuted = Color(0xFF7C87A6);

  /// Lebih pekat daripada versi terang: bayangan tipis di atas latar gelap
  /// tidak menghasilkan kedalaman apa pun.
  static const Color shadowDark = Color(0x8C060A16);
  static const Color shadowLight = Color(0x1F7C93D6);
}

/// Palet TERANG — biru lembut.
class _T {
  const _T._();

  /// Sedikit kebiruan, bukan putih murni: di atas putih, highlight kiri-atas
  /// hilang sama sekali dan bentuknya kembali menjadi kartu biasa.
  static const Color background = Color(0xFFEFF1FA);
  static const Color surface = Color(0xFFF6F8FE);

  /// Biru agak gelap, sesuai arah tema. Di atas latar terang warna utama
  /// harus lebih GELAP dari latarnya — kebalikan dari mode gelap.
  static const Color primary = Color(0xFF2B54C4);
  static const Color primarySoft = Color(0xFFDDE5FB);
  static const Color secondary = Color(0xFF0E9B8C);

  /// Warna status dibuat lebih pekat daripada versi mode gelap: nilai cerah
  /// seperti #34D399 di atas latar terang kehilangan kontras terhadap teks
  /// putih di dalam lencana.
  static const Color success = Color(0xFF1E9E5A);
  static const Color successSoft = Color(0xFFDCF6E8);
  static const Color warning = Color(0xFFB9740B);
  static const Color warningSoft = Color(0xFFFDEFD8);
  static const Color danger = Color(0xFFCE2F35);
  static const Color dangerSoft = Color(0xFFFBE3E4);
  static const Color info = Color(0xFF2470CE);
  static const Color infoSoft = Color(0xFFDFEBFE);

  static const Color textStrong = Color(0xFF1B2540);
  static const Color textBody = Color(0xFF44496B);
  static const Color textMuted = Color(0xFF7B819E);

  static const Color shadowDark = Color(0x2E9AA5C8);

  /// Nyaris putih penuh — inilah yang memberi kesan permukaan menggembung
  /// pada latar terang.
  static const Color shadowLight = Color(0xF2FFFFFF);
}
