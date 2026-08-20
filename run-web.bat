@echo off
setlocal

rem ======================================================================
rem  Jargon GO - debug di browser.
rem
rem  Skrip ini HANYA menjalankan Flutter. API (cargo run), dashboard
rem  (php artisan serve), dan database dijalankan terpisah - pakai dev.bat
rem  di akar repositori untuk membuka semuanya sekaligus dalam tab-tab
rem  Windows Terminal.
rem
rem  Yang BISA diuji di browser: login NIK/NISN, Beranda, Absensi
rem  (pemantauan), Panic Button, dan Pemberkasan.
rem
rem  Yang TIDAK bisa: mode kios absensi wajah. Kamera, ML Kit, dan model
rem  TFLite hanya ada di aplikasi Android/iOS - membuka Kios di web akan
rem  menampilkan halaman penjelasan, bukan layar kamera.
rem
rem  Pemakaian:
rem    run-web.bat                 :5000, API http://127.0.0.1:8080
rem    run-web.bat 5001            ganti port web
rem    run-web.bat 5000 http://192.168.1.10:8080     ganti alamat API
rem    run-web.bat 5000 - server   jangan buka browser, layani saja
rem
rem  Alamat API juga bisa diubah SAAT APLIKASI BERJALAN lewat tombol
rem  alamat server di layar login - tidak perlu menjalankan ulang.
rem ======================================================================

set "WEB_PORT=%~1"
if "%WEB_PORT%"=="" set "WEB_PORT=5000"

set "API_URL=%~2"
if "%API_URL%"=="" set "API_URL=http://127.0.0.1:8080"
if "%API_URL%"=="-" set "API_URL=http://127.0.0.1:8080"

rem 127.0.0.1, bukan localhost. Keduanya menunjuk mesin yang sama, tetapi
rem bagi CORS keduanya origin YANG BERBEDA - halaman di 127.0.0.1:5000 yang
rem memanggil localhost:8080 dihitung lintas origin oleh browser.
set "WEB_HOST=127.0.0.1"

rem ----------------------------------------------------------------------
rem  Browser
rem
rem  Flutter memakai variabel CHROME_EXECUTABLE untuk device "chrome".
rem  Brave berbasis Chromium, jadi cukup diarahkan ke sana - DevTools dan
rem  hot reload tetap bekerja penuh.
rem ----------------------------------------------------------------------
set "BRAVE=%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe"
if not exist "%BRAVE%" set "BRAVE=%ProgramFiles(x86)%\BraveSoftware\Brave-Browser\Application\brave.exe"
if not exist "%BRAVE%" set "BRAVE=%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe"

set "DEVICE=chrome"
set "BROWSER_LABEL=Chrome"

if exist "%BRAVE%" (
    set "CHROME_EXECUTABLE=%BRAVE%"
    set "BROWSER_LABEL=Brave"
)

rem Mode "server": Flutter hanya melayani, tidak membuka browser. Berguna
rem bila ingin memakai profil Brave yang sudah ada (lengkap dengan ekstensi
rem dan login), bukan profil sementara yang dibuat Flutter.
if /i "%~3"=="server" (
    set "DEVICE=web-server"
    set "BROWSER_LABEL=buka manual"
)

echo.
echo   Jargon GO - debug web
echo   -------------------------------------------
echo   Aplikasi : http://%WEB_HOST%:%WEB_PORT%
echo   API      : %API_URL%
echo   Browser  : %BROWSER_LABEL%
echo.
echo   Skrip ini TIDAK menjalankan cargo/API. Jalankan API di tab lain:
echo       cd ..\jargon-be\api ^&^& cargo run
echo   atau pakai dev.bat di akar repositori untuk semua sekaligus.
echo.
echo   CORS_ALLOWED_ORIGINS di API harus memuat http://%WEB_HOST%:%WEB_PORT%
echo   ^(bawaannya `*`, sudah cukup untuk lokal^).
echo.
echo   r = hot reload   R = hot restart   q = keluar
echo   -------------------------------------------
echo.

rem --web-hostname + --web-port dibuat tetap agar origin-nya stabil; tanpa
rem itu Flutter memilih port acak dan CORS gagal setiap kali portnya ganti.
rem
rem SENGAJA TIDAK memakai --disable-web-security. Mematikan CORS di browser
rem membuat masalah konfigurasi tidak terlihat saat debug lalu muncul di
rem produksi, tempat tidak ada flag yang bisa mematikannya. Bila permintaan
rem diblokir, perbaiki CORS_ALLOWED_ORIGINS di API - itu memang yang salah.
flutter run -d %DEVICE% ^
  --web-hostname=%WEB_HOST% ^
  --web-port=%WEB_PORT% ^
  --dart-define=API_BASE_URL=%API_URL%

endlocal
