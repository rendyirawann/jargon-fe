# jargon-fe — Jargon GO

Aplikasi Flutter Super Apps Dinas Pendidikan Provinsi Sumatera Utara. Satu APK
melayani perangkat sekolah maupun ponsel pribadi:

| Mode | Perangkat | Autentikasi | Layar |
|---|---|---|---|
| **Kios** | tablet di gerbang / ruang kelas | device token | pemindaian wajah siswa |
| **Pendaftaran** | tablet bermode `enroll` | device token | ambil sampel wajah |
| **Jargon GO** | ponsel siswa, orang tua, guru | akun (JWT, login NIK/NISN) | absensi, Panic Button, pemberkasan |

Semuanya digabung karena sekolah di daerah lebih mudah mendistribusikan satu
aplikasi, dan karena guru yang mendaftarkan wajah siswa memakai perangkat yang
sama dengan yang dipakai memantau.

---

## Tiga menu Jargon GO

| Menu | Siswa | Orang Tua | Guru / Kepala Sekolah |
|---|---|---|---|
| **Absensi** | datanya sendiri | **hanya anaknya** | siswa di sekolahnya |
| **Panic Button** | tulis & baca (anonim) | tulis & baca (anonim) | baca; kepsek menangani |
| **Pemberkasan** | — | — | unggah & pantau berkas |

Menu yang tampil **ditentukan server** lewat `available_menus` pada
`GET /v1/me/home`, dihitung dari izin pengguna. Menambah menu untuk sebuah
peran karenanya tidak memerlukan rilis aplikasi baru.

**Menu Absensi tidak punya tombol "absen".** Itu disengaja: kehadiran hanya
dapat dicatat lewat pengenalan wajah di tablet sekolah. Tombol absen di
aplikasi akan membuat siswa bisa mengabsenkan diri dari rumah dan meniadakan
seluruh alasan sistem ini dibangun.

**Panic Button menampilkan handel anonim, tidak pernah nama.** Aplikasi tidak
menerima `author_user_id` dari API dalam bentuk apa pun — bukan disembunyikan
di klien, melainkan memang tidak dikirim.

---

## Tema: claymorphism

Palet dan komponen dasar ada di [`lib/core/theme/`](lib/core/theme/):

* `clay_theme.dart` — palet, pasangan bayangan (`raised`/`pressed`), label &
  warna status.
* `clay_widgets.dart` — `ClaySurface`, `ClayCard`, `ClayButton`, `ClayField`,
  `ClayBadge`, `ClayNavBar`, dan kawan-kawan.

Ciri khasnya: radius besar (26), **dua** bayangan berlawanan arah (gelap di
kanan-bawah, terang di kiri-atas) sehingga permukaan tampak timbul dari latar,
dan tanpa garis tepi. Kolom isian memakai varian `sunken` — gradien tipis yang
meniru bayangan ke dalam, karena Flutter tidak punya inner shadow.

Bila menambah layar, pakai widget dari berkas itu alih-alih `Card`/`ElevatedButton`
bawaan; satu komponen Material di tengah layar clay akan terlihat seperti
tempelan.

---

## Menjalankan

### Di dalam container (bagian dari sistem lengkap)

Aplikasi ini termasuk dalam `docker compose` di akar repositori. Dari akar:

```bat
setup.bat        :: Windows — sekali saja
docker compose up -d
```

Aplikasi terbuka di <http://localhost/>, dilayani nginx yang sama dengan API.
Karena itu ia dibangun dengan `--dart-define=API_SAME_ORIGIN=true`: alamat
API diambil dari **origin halaman saat berjalan**, bukan dipaku saat build.
Itu yang membuat image yang sama bekerja di `localhost`, di IP LAN, maupun di
balik nama domain — tanpa dibangun ulang.

Berkasnya: [`Dockerfile`](Dockerfile) dan [`docker/web.conf`](docker/web.conf).

### Debug cepat di browser

Cara tercepat menguji menu Jargon GO tanpa emulator atau kabel USB:

```bat
run-web.bat
```

Aplikasi terbuka di <http://127.0.0.1:5000>, memakai API di
`http://127.0.0.1:8080`. **Brave dipakai otomatis** bila terpasang — Flutter
membaca variabel `CHROME_EXECUTABLE`, dan Brave berbasis Chromium sehingga
hot reload serta DevTools tetap bekerja penuh.

```bat
run-web.bat 5001                                 :: ganti port web
run-web.bat 5000 http://192.168.1.10:8080        :: ganti alamat API
run-web.bat 5000 - server                        :: jangan buka browser
```

Mode `server` hanya melayani di <http://127.0.0.1:5000> tanpa membuka
browser — pakai ini bila ingin memakai profil Brave Anda sendiri (lengkap
dengan ekstensi dan login), bukan profil sementara yang dibuat Flutter.

Skrip ini **tidak** menjalankan `cargo`. API dijalankan terpisah
(`cd jargon-be/api && cargo run`), atau sekaligus lewat `dev.bat`.

Untuk menyalakan **semuanya sekaligus** (PostgreSQL, API + Swagger, dashboard,
dan aplikasi web) dalam satu jendela Windows Terminal, jalankan
[`dev.bat`](../dev.bat) di akar repositori. Tab Web-nya memanggil
`run-web.bat` ini setelah API siap, jadi layar login tidak langsung
menampilkan "tidak dapat menghubungi server". Rincian tiap tab ada di
[`dev-manual.txt`](../dev-manual.txt).

| Yang bisa diuji di browser | Yang **tidak** bisa |
|---|---|
| Login NIK/NISN, Beranda | Mode kios absensi wajah |
| Absensi (pemantauan) | Pendaftaran wajah |
| Panic Button (tulis, baca, komentar) | |
| Pemberkasan (unggah, pantau) | |

Mode kios butuh kamera, ML Kit, dan model TFLite — ketiganya hanya ada di
aplikasi Android/iOS. Di web, tombol "Buka Kios" menampilkan halaman
penjelasan, bukan layar kamera yang gelap.

Dua penyesuaian yang membuat web bisa dibangun sama sekali:

* **Antrean offline** memakai SQLite di perangkat dan memori di browser
  (`data/offline_queue*.dart`). `sqflite` tidak berjalan di web.
* **Mode kios** dipisahkan di balik `features/kiosk/kiosk_entry.dart`.
  `tflite_flutter` berdiri di atas `dart:ffi` yang **tidak dapat dikompilasi
  ke web sama sekali** — tanpa pemisahan ini, `flutter run -d chrome` gagal
  saat build, bukan saat dijalankan.

> **CORS.** Browser memblokir permintaan lintas origin sebelum sampai ke
> server. `CORS_ALLOWED_ORIGINS` pada API harus memuat
> `http://127.0.0.1:5000` (bawaannya `*`, sudah cukup untuk lokal). Aplikasi
> Android/iOS tidak terpengaruh — CORS adalah aturan browser.
>
> `127.0.0.1` dan `localhost` menunjuk mesin yang sama tetapi merupakan
> **origin yang berbeda**. Karena itu port, host aplikasi, dan alamat API
> semuanya memakai `127.0.0.1` — mencampur keduanya menghasilkan permintaan
> lintas origin yang tidak Anda niatkan.

### Menjalankan di perangkat

**1. Siapkan model.** Salin model TFLite ke
`assets/models/mobilefacenet.tflite`. Persyaratan dan alasan mengapa berkas ini
tidak ada di repositori: [`assets/models/README.md`](assets/models/README.md).

**2. Jalankan.**

```bash
flutter pub get

# Emulator Android (10.0.2.2 = localhost mesin host)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# Produksi
flutter build apk --release \
  --dart-define=API_BASE_URL=https://absensi.disdik.sumutprov.go.id \
  --dart-define=FACE_MODEL_VERSION=mobilefacenet-v1 \
  --dart-define=FACE_EMBEDDING_DIM=512
```

---

## Mengatur alamat API

Alamat server ada di **dua tempat**, dengan tujuan berbeda.

### Alamat server — bisa diubah saat aplikasi berjalan

Layar **login** dan **Profil** punya tombol alamat server. Alamat yang diisi
diuji ke `/health` lebih dulu, lalu disimpan di perangkat dan dipakai sampai
diubah lagi. **Tidak perlu membangun ulang aplikasi.**

Tombolnya sengaja ada juga di layar login: kalau alamatnya salah, pengguna
tidak bisa masuk — sehingga layar Profil yang ada di balik login tidak akan
pernah terjangkau untuk memperbaikinya.

| Tempat menjalankan | Alamat |
|---|---|
| Debug di browser | `http://127.0.0.1:8080` |
| Emulator Android | `http://10.0.2.2:8080` |
| Ponsel/tablet fisik | `http://<IP laptop>:8080` (`ipconfig` → IPv4) |
| Produksi | `https://absensi.disdik.sumutprov.go.id` |

Untuk perangkat fisik, ponsel harus berada di Wi-Fi yang sama dan port 8080
perlu diizinkan Windows Firewall.

Kodenya: [`lib/core/api_config.dart`](lib/core/api_config.dart) (nilai aktif +
validasi) dan [`lib/features/shell/server_settings_screen.dart`](lib/features/shell/server_settings_screen.dart) (layarnya).

### Daftar endpoint — satu berkas

Semua path API yang dipanggil aplikasi terkumpul di
[`lib/core/api_routes.dart`](lib/core/api_routes.dart). Tidak ada satu pun
string `'/v1/...'` yang tersebar di layar atau repository.

```dart
// Naikkan versi API: satu baris, seluruh aplikasi ikut.
static const String prefix = '/v1';

static const String panicReports = '$prefix/panic/reports';
static String panicComments(String id) => '$panicReports/$id/comments';
```

Berkas itu juga memuat aturan kredensial per endpoint (`needsDeviceToken`,
`needsNoCredential`), supaya menambah endpoint baru berarti melihat aturan
kredensialnya pada saat yang sama. Salah jenis kredensial menghasilkan 401
yang membingungkan: token **ada**, hanya jenisnya yang keliru.

### Nilai bawaan saat build

| Kunci `--dart-define` | Bawaan | Keterangan |
|---|---|---|
| `API_BASE_URL` | web `127.0.0.1:8080`, lainnya `10.0.2.2:8080` | alamat awal; dapat ditimpa pengguna |
| `FACE_MODEL_VERSION` | `mobilefacenet-v1` | **harus sama** dengan server |
| `FACE_EMBEDDING_DIM` | `512` | **harus sama** dengan server & model |
| `FACE_MODEL_INPUT` | `112` | sisi input model (piksel) |
| `KIOSK_ROTATION` | `0` | isi bila tablet dipasang miring |

`FACE_MODEL_VERSION` yang tidak cocok akan ditolak server dengan pesan
"Perbarui aplikasi". Itu perilaku yang diinginkan: embedding dari model
berbeda tidak sebanding, dan mencocokkannya menghasilkan identifikasi **acak**,
bukan sekadar akurasi lebih rendah.

---

## Memasangkan tablet

1. Operator membuat perangkat di `/admin/devices` dan menerima **kode pairing
   8 digit** (berlaku 30 menit, sekali pakai).
2. Di aplikasi: **Pasangkan Perangkat** → masukkan kode.
3. Tablet menerima device token permanen. Token **tidak dapat dilihat lagi**;
   bila hilang, buat kode pairing baru.

Kredensial disimpan di Keystore (Android) / Keychain (iOS), bukan di
SharedPreferences — tablet dipasang di ruang publik.

---

## Yang terjadi pada satu pemindaian

```
frame kamera
   ↓ ML Kit: deteksi wajah, ukuran, sudut kepala
   ↓ liveness pasif: kedip mata + gerak kepala mikro
   ↓ crop dengan margin 25% → 112×112
   ↓ TFLite: embedding 512-d → L2-normalize
   ↓
POST /v1/kiosk/recognize   { embedding, liveness, nonce, client_time }
   ↓
server: cocokkan dalam sekolah ini → catat absensi → buang embedding
   ↓
layar: nama siswa, kelas, jam masuk, status
```

Yang dikirim hanya **vektor** (~8 KB), bukan gambar (~200 KB). Untuk sekolah
berjaringan lambat, ini perbedaan antara "instan" dan "tidak bisa dipakai".

---

## Ketahanan jaringan

Banyak sekolah berada di daerah dengan jaringan tidak stabil. Bila tablet
menolak absen saat jaringan mati, siswa yang sudah datang akan tercatat alfa
dan orang tuanya menerima notifikasi yang salah.

Karena itu pemindaian yang gagal terkirim masuk **antrean lokal** (SQLite):

* Hanya vektor + waktu tangkap yang disimpan — **tidak ada gambar**.
* Baris dihapus segera setelah server menerimanya.
* Umur maksimum 18 jam; yang lebih tua dibuang dan **dilaporkan** ke operator,
  tidak hilang diam-diam.
* Jumlah antrean tampil sebagai lencana di layar kios.
* Penolakan yang bersifat aturan (di luar jam, wajah tak dikenal) tidak masuk
  antrean — mengirim ulangnya tidak akan mengubah apa pun.

---

## Struktur kode

```
lib/
├── core/
│   ├── config.dart           nilai bawaan dari --dart-define
│   ├── api_config.dart       ALAMAT SERVER aktif (bisa diubah saat berjalan)
│   ├── api_routes.dart       DAFTAR ENDPOINT — satu-satunya tempat path API
│   ├── api_client.dart       HTTP: pilih kredensial, bongkar envelope, terjemahkan galat
│   ├── authed_image.dart     gambar dari /files/* yang membawa token
│   ├── storage.dart          Keystore untuk kredensial, prefs untuk konfigurasi
│   ├── failure.dart          ApiFailure / FaceFailure
│   └── theme/
│       ├── clay_theme.dart   palet, bayangan, label status
│       └── clay_widgets.dart komponen claymorphism
├── data/
│   ├── models.dart               DTO absensi & autentikasi
│   ├── jargon_models.dart        DTO beranda, Panic Button, pemberkasan
│   ├── offline_queue.dart        antarmuka antrean + pemilih implementasi
│   ├── offline_queue_sqflite.dart  antrean SQLite (Android/iOS)
│   ├── offline_queue_memory.dart   antrean di memori (web/debug)
│   └── repository.dart           satu-satunya pintu ke API
└── features/
    ├── kiosk/
    │   ├── kiosk_entry.dart      shim: kios asli di perangkat, penjelasan di web
    │   ├── face_engine.dart      ML Kit + TFLite + liveness
    │   ├── kiosk_controller.dart alur frame, heartbeat, sinkronisasi
    │   └── kiosk_screen.dart     layar yang dilihat siswa
    ├── enroll/                   pendaftaran wajah
    ├── auth/                     login NIK/NISN
    ├── shell/                    beranda, profil, setelan alamat server
    ├── absensi/                  pemantauan absensi
    ├── panic/                    beranda, tulis, detail pengaduan
    ├── berkas/                   pemberkasan kepegawaian
    ├── monitor/                  monitoring guru
    ├── pairing/                  pairing perangkat
    └── home/                     menu utama perangkat sekolah
```

Dua berkas yang punya kembaran adalah titik pisah platform: `offline_queue_*`
dan `kiosk_entry_*`. Keduanya dipilih otomatis lewat conditional import, dan
alasannya ditulis di berkas induknya.

---

## Pengujian

```bash
flutter analyze     # bersih, tanpa peringatan
flutter test        # 29 pengujian unit
flutter build web   # pastikan debug web tidak rusak
```

Pengujian difokuskan pada hal yang paling berkonsekuensi: normalisasi vektor
(menentukan apakah pencocokan bisa dipercaya), pembacaan respons API
(menentukan apa yang dilihat siswa di layar), pemetaan profil pengguna —
termasuk memastikan label peran datang dari **server**, sehingga peran baru
tidak memerlukan rilis aplikasi — serta penanganan alamat server dan aturan
kredensial per endpoint.

`flutter build web` layak dijalankan sebelum commit meskipun target
utamanya Android: menambah satu impor yang menyentuh `dart:ffi` akan merusak
debug web tanpa memunculkan peringatan apa pun di `flutter analyze`.

---

## Batasan yang diketahui

**Liveness bersifat pasif.** Deteksi kedip dan gerak kepala mikro menghentikan
penyalahgunaan yang paling umum di lapangan — mengarahkan foto cetak atau layar
ponsel ke kamera. Ini **bukan** anti-spoof kelas tinggi: serangan dengan video
wajah bergerak masih mungkin. Titik sisipan untuk model anti-spoof khusus sudah
disiapkan di `FaceEngine.analyze()`.

**Model tidak disertakan** dalam repositori (lisensi dan ukuran).

Backend: [`../jargon-be`](../jargon-be) ·
Arsitektur: [`../jargon-be/docs/ARCHITECTURE.md`](../jargon-be/docs/ARCHITECTURE.md)
