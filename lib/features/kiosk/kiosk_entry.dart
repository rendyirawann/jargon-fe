/// Pintu masuk mode kios.
///
/// MENGAPA LEWAT SHIM
///
/// `KioskScreen` menarik `face_engine.dart`, yang memakai `tflite_flutter` —
/// dan paket itu berdiri di atas `dart:ffi`, yang **tidak dapat dikompilasi ke
/// web sama sekali**. Begitu `main.dart` punya jalur impor yang sampai ke sana,
/// `flutter run -d chrome` gagal saat build, bukan gagal saat dijalankan.
///
/// Shim ini memutus jalur itu: di Android/iOS ia mengekspor pembuka layar kios
/// yang sebenarnya, di web ia mengekspor layar penjelasan. Pemanggilnya cukup
/// menulis `openKiosk(context)` tanpa perlu tahu ada dua dunia.
library;

export 'kiosk_entry_unsupported.dart'
    if (dart.library.io) 'kiosk_entry_native.dart';
