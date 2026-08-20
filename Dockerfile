# =====================================================================
# Jargon GO — aplikasi web
#
# Build dua tahap: SDK Flutter hanya ada di tahap pertama, sehingga image
# akhir berisi berkas statis saja (~30 MB, bukan ~3 GB).
#
# Aplikasi ini dilayani di BELAKANG nginx penyatu bersama API. Karena itu
# ia dibangun dengan API_SAME_ORIGIN=true: alamat API diambil dari origin
# halaman saat berjalan, bukan dipaku saat build. Itu yang membuat image
# ini bisa dijalankan di mesin mana pun — dibuka lewat localhost, IP LAN,
# atau nama domain, semuanya bekerja tanpa membangun ulang.
#
# Mode kios (absensi wajah) TIDAK tersedia di build ini: kamera, ML Kit,
# dan TFLite hanya ada di aplikasi Android/iOS. Lihat
# lib/features/kiosk/kiosk_entry.dart.
# =====================================================================

# Disematkan, bukan `:stable`, agar image yang dibangun bulan depan
# menghasilkan bundel yang sama. Flutter stable bergerak cepat, dan
# perbedaan versi pernah mengubah API paket (lihat catatan file_picker di
# README).
#
# Nilainya mengikuti tag yang BENAR-BENAR ADA di ghcr.io/cirruslabs/flutter,
# yang hanya memuat rilis minor (3.44.0), bukan setiap patch. Mesin
# pengembang boleh memakai patch yang lebih baru — batasan SDK di
# pubspec.yaml yang menjaga keduanya tetap sepadan.
#
# Memeriksa tag yang tersedia:
#   TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:cirruslabs/flutter:pull" | jq -r .token)
#   curl -s -H "Authorization: Bearer $TOKEN" \
#        "https://ghcr.io/v2/cirruslabs/flutter/tags/list?n=1000" | jq -r '.tags[]'
ARG FLUTTER_VERSION=3.44.0
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS builder

WORKDIR /build

# 1) Manifest lebih dulu -> layer dependensi yang stabil. Perubahan pada
#    lib/ tidak memaksa unduh ulang seluruh paket pub.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 2) Kode dan aset.
COPY analysis_options.yaml ./
COPY assets ./assets
COPY web ./web
COPY lib ./lib

# `flutter pub get` diulang karena pubspec.yaml menyebut folder aset yang
# baru ada setelah COPY di atas.
RUN flutter pub get

ARG API_BASE_URL=""
ARG BUILD_MODE=release

# Awalan path tempat aplikasi dilayani. `/` bila di akar domain.
#
# Bundel web memuat asetnya lewat path absolut, jadi bila dilayani di
# subpath tanpa --base-href ia meminta /assets/... di akar domain dan
# mendapat 404 - halaman putih tanpa pesan galat apa pun.
ARG BASE_HREF=/

RUN flutter build web \
        --${BUILD_MODE} \
        --base-href="${BASE_HREF}" \
        --dart-define=API_SAME_ORIGIN=true \
        --dart-define=API_BASE_URL="${API_BASE_URL}"

# ---------------------------------------------------------------------
# Runtime: berkas statis saja.
# ---------------------------------------------------------------------
FROM nginx:1.27-alpine

COPY --from=builder /build/build/web /usr/share/nginx/html
COPY docker/web.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
