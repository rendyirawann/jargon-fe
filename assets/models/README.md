# Model Embedding Wajah

Direktori ini harus berisi **satu** berkas:

```
assets/models/mobilefacenet.tflite
```

Berkas model tidak disertakan dalam repositori karena dua alasan: ukurannya
beberapa megabita (tidak layak masuk git), dan lisensi setiap model pra-latih
berbeda sehingga harus dipilih secara sadar oleh Dinas.

## Persyaratan model

| Properti | Nilai wajib |
|---|---|
| Format | TensorFlow Lite (`.tflite`) |
| Input | `[1, 112, 112, 3]`, float32, dinormalisasi ke `[-1, 1]` |
| Output | `[1, 512]`, float32 |
| Arsitektur | MobileFaceNet / ArcFace 512-d |

Ukuran input dan dimensi output dapat diubah lewat `--dart-define`
(`FACE_MODEL_INPUT`, `FACE_EMBEDDING_DIM`) bila memakai model lain, **tetapi
nilainya harus sama dengan konfigurasi server** (`FACE_EMBEDDING_DIM` pada
`jargon-be/api/.env`).

## Aturan yang tidak boleh dilanggar

**Versi model di aplikasi, di server, dan di dashboard harus sama.**

Embedding adalah koordinat dalam ruang vektor yang dipelajari oleh satu model
tertentu. Vektor dari model berbeda tidak sebanding — mencocokkannya tidak
menghasilkan "akurasi yang lebih rendah", melainkan **identifikasi acak**:
siswa A bisa dikenali sebagai siswa B.

Karena itu setiap request absensi menyertakan `model_version`, dan server
menolak request yang versinya tidak cocok. Rantainya:

```
FACE_MODEL_VERSION (Flutter --dart-define)
        ==
FACE_MODEL_VERSION (jargon-be/api/.env)
        ==
face_embeddings.model_version (kolom di PostgreSQL)
```

## Mengganti model

Mengganti model berarti **seluruh embedding tersimpan menjadi tidak berlaku**.
Langkahnya:

1. Naikkan `FACE_MODEL_VERSION` di server dan di aplikasi (mis. ke
   `mobilefacenet-v2`).
2. Hitung ulang embedding dari gambar pendaftaran yang tersimpan di storage
   (inilah alasan gambar pendaftaran diarsipkan — tanpa itu, 700.000 siswa
   harus difoto ulang satu per satu).
3. Rilis aplikasi baru ke semua tablet.

Selama masa transisi, tablet dengan versi lama akan ditolak server dengan
pesan "Perbarui aplikasi", bukan mencatat absensi yang salah.

## Catatan tentang liveness

Aplikasi menerapkan liveness **pasif** (deteksi kedip dan gerak kepala mikro)
di `lib/features/kiosk/face_engine.dart`. Ini menghentikan penyalahgunaan
paling umum di lapangan — mengarahkan foto cetak atau layar ponsel ke kamera —
tetapi bukan anti-spoof kelas tinggi.

Bila diperlukan jaminan lebih kuat, tambahkan model anti-spoof khusus di
direktori ini dan panggil dari `FaceEngine.analyze()` sebelum embedding
dihitung.
