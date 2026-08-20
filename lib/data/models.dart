/// Model data yang dipertukarkan dengan API.
///
/// Ditulis manual (tanpa code generation) agar proyek bisa dibangun dengan
/// `flutter build` saja — tim di daerah tidak perlu menjalankan build_runner
/// sebelum merilis APK.
library;

// =====================================================================
// Perangkat
// =====================================================================

/// Hasil pairing perangkat. Token hanya diberikan sekali oleh server.
class PairResult {
  PairResult({
    required this.deviceId,
    required this.deviceCode,
    required this.deviceName,
    required this.schoolId,
    required this.schoolName,
    required this.classroomId,
    required this.classroomName,
    required this.mode,
    required this.placement,
    required this.deviceToken,
    required this.hmacSecret,
    required this.config,
  });

  final String deviceId;
  final String deviceCode;
  final String deviceName;
  final String schoolId;
  final String schoolName;
  final String? classroomId;
  final String? classroomName;
  final String mode;
  final String placement;
  final String deviceToken;
  final String hmacSecret;
  final DeviceConfig config;

  factory PairResult.fromJson(Map<String, dynamic> j) => PairResult(
        deviceId: j['device_id'] as String,
        deviceCode: j['device_code'] as String? ?? '-',
        deviceName: j['device_name'] as String? ?? '-',
        schoolId: j['school_id'] as String,
        schoolName: j['school_name'] as String? ?? '-',
        classroomId: j['classroom_id'] as String?,
        classroomName: j['classroom_name'] as String?,
        mode: j['mode'] as String? ?? 'auto',
        placement: j['placement'] as String? ?? 'gate',
        deviceToken: j['device_token'] as String,
        hmacSecret: j['hmac_secret'] as String? ?? '',
        config: DeviceConfig.fromJson(
          (j['config'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  /// Profil yang disimpan lokal — TANPA token dan secret, yang masuk ke
  /// secure storage terpisah.
  Map<String, dynamic> toProfileJson() => {
        'device_id': deviceId,
        'device_code': deviceCode,
        'device_name': deviceName,
        'school_id': schoolId,
        'school_name': schoolName,
        'classroom_id': classroomId,
        'classroom_name': classroomName,
        'mode': mode,
        'placement': placement,
        'model_version': config.modelVersion,
        'embedding_dim': config.embeddingDim,
      };
}

class DeviceConfig {
  const DeviceConfig({
    required this.embeddingDim,
    required this.modelVersion,
    required this.matchThreshold,
    required this.minLiveness,
    required this.scanCooldownSeconds,
    required this.heartbeatIntervalSeconds,
  });

  final int embeddingDim;
  final String modelVersion;
  final double matchThreshold;
  final double minLiveness;
  final int scanCooldownSeconds;
  final int heartbeatIntervalSeconds;

  factory DeviceConfig.fromJson(Map<String, dynamic> j) => DeviceConfig(
        embeddingDim: (j['embedding_dim'] as num?)?.toInt() ?? 512,
        modelVersion: j['model_version'] as String? ?? 'mobilefacenet-v1',
        matchThreshold: (j['match_threshold'] as num?)?.toDouble() ?? 0.62,
        minLiveness: (j['min_liveness'] as num?)?.toDouble() ?? 0.5,
        scanCooldownSeconds:
            (j['scan_cooldown_seconds'] as num?)?.toInt() ?? 60,
        heartbeatIntervalSeconds:
            (j['heartbeat_interval_seconds'] as num?)?.toInt() ?? 120,
      );
}

/// Jendela jam absensi hari ini, dari balasan heartbeat.
class TodayWindows {
  const TodayWindows({
    required this.isActiveDay,
    required this.isHoliday,
    this.holidayName,
    this.checkInOpensAt,
    this.checkInDueAt,
    this.checkInClosesAt,
    this.checkOutOpensAt,
    this.checkOutClosesAt,
  });

  final bool isActiveDay;
  final bool isHoliday;
  final String? holidayName;
  final String? checkInOpensAt;
  final String? checkInDueAt;
  final String? checkInClosesAt;
  final String? checkOutOpensAt;
  final String? checkOutClosesAt;

  factory TodayWindows.fromJson(Map<String, dynamic> j) => TodayWindows(
        isActiveDay: j['is_active_day'] as bool? ?? true,
        isHoliday: j['is_holiday'] as bool? ?? false,
        holidayName: j['holiday_name'] as String?,
        checkInOpensAt: j['check_in_opens_at'] as String?,
        checkInDueAt: j['check_in_due_at'] as String?,
        checkInClosesAt: j['check_in_closes_at'] as String?,
        checkOutOpensAt: j['check_out_opens_at'] as String?,
        checkOutClosesAt: j['check_out_closes_at'] as String?,
      );
}

class HeartbeatResult {
  const HeartbeatResult({
    required this.rosterVersion,
    required this.commands,
    required this.config,
    this.todayWindows,
  });

  final int rosterVersion;
  final List<String> commands;
  final DeviceConfig config;
  final TodayWindows? todayWindows;

  factory HeartbeatResult.fromJson(Map<String, dynamic> j) => HeartbeatResult(
        rosterVersion: (j['roster_version'] as num?)?.toInt() ?? 0,
        commands: (j['commands'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        config: DeviceConfig.fromJson(
          (j['config'] as Map<String, dynamic>?) ?? const {},
        ),
        todayWindows: j['today_windows'] is Map<String, dynamic>
            ? TodayWindows.fromJson(j['today_windows'] as Map<String, dynamic>)
            : null,
      );
}

// =====================================================================
// Pengenalan
// =====================================================================

/// Tindakan yang dilakukan server atas satu pemindaian.
enum RecognizeAction {
  checkedIn,
  checkedOut,
  alreadyRecorded,
  noMatch,
  lowConfidence,
  rejected,

  /// Khusus klien: tersimpan di antrean lokal karena jaringan mati.
  queuedOffline;

  static RecognizeAction parse(String? raw) => switch (raw) {
        'checked_in' => RecognizeAction.checkedIn,
        'checked_out' => RecognizeAction.checkedOut,
        'already_recorded' => RecognizeAction.alreadyRecorded,
        'no_match' => RecognizeAction.noMatch,
        'low_confidence' => RecognizeAction.lowConfidence,
        _ => RecognizeAction.rejected,
      };

  bool get isSuccess =>
      this == RecognizeAction.checkedIn || this == RecognizeAction.checkedOut;

  bool get isNeutral =>
      this == RecognizeAction.alreadyRecorded ||
      this == RecognizeAction.queuedOffline;
}

class RecognizedStudent {
  const RecognizedStudent({
    required this.id,
    required this.fullName,
    this.nis,
    this.classroomName,
    this.schoolName,
    this.photoUrl,
  });

  final String id;
  final String fullName;
  final String? nis;
  final String? classroomName;
  final String? schoolName;
  final String? photoUrl;

  factory RecognizedStudent.fromJson(Map<String, dynamic> j) =>
      RecognizedStudent(
        id: j['id'] as String,
        fullName: j['full_name'] as String? ?? '-',
        nis: j['nis'] as String?,
        classroomName: j['classroom_name'] as String?,
        schoolName: j['school_name'] as String?,
        photoUrl: j['photo_url'] as String?,
      );
}

class RecognizeResult {
  const RecognizeResult({
    required this.matched,
    required this.action,
    required this.message,
    this.student,
    this.status,
    this.checkInTime,
    this.checkOutTime,
    this.lateMinutes = 0,
    this.similarity,
    this.processingMs,
  });

  final bool matched;
  final RecognizeAction action;
  final String message;
  final RecognizedStudent? student;

  /// Status absensi (`hadir`, `terlambat`, ...) bila tercatat.
  final String? status;
  final String? checkInTime;
  final String? checkOutTime;
  final int lateMinutes;
  final double? similarity;
  final int? processingMs;

  factory RecognizeResult.fromJson(Map<String, dynamic> j) {
    final attendance = j['attendance'] as Map<String, dynamic>?;
    return RecognizeResult(
      matched: j['matched'] as bool? ?? false,
      action: RecognizeAction.parse(j['action'] as String?),
      message: j['message'] as String? ?? '',
      student: j['student'] is Map<String, dynamic>
          ? RecognizedStudent.fromJson(j['student'] as Map<String, dynamic>)
          : null,
      status: attendance?['status'] as String?,
      checkInTime: _hhmm(attendance?['check_in_at'] as String?),
      checkOutTime: _hhmm(attendance?['check_out_at'] as String?),
      lateMinutes: (attendance?['late_minutes'] as num?)?.toInt() ?? 0,
      similarity: (j['similarity'] as num?)?.toDouble(),
      processingMs: (j['processing_ms'] as num?)?.toInt(),
    );
  }

  /// Hasil untuk pemindaian yang hanya masuk antrean lokal.
  factory RecognizeResult.queued() => const RecognizeResult(
        matched: false,
        action: RecognizeAction.queuedOffline,
        message: 'Jaringan terputus. Absensi disimpan dan akan dikirim '
            'otomatis saat jaringan kembali.',
      );

  factory RecognizeResult.error(String message) => RecognizeResult(
        matched: false,
        action: RecognizeAction.rejected,
        message: message,
      );

  /// Ubah timestamp ISO-8601 UTC menjadi jam lokal `HH:mm`.
  static String? _hhmm(String? iso) {
    if (iso == null) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// =====================================================================
// Roster & monitoring
// =====================================================================

class RosterEntry {
  const RosterEntry({
    required this.studentId,
    required this.fullName,
    this.nis,
    this.classroomName,
    required this.faceEnrolled,
  });

  final String studentId;
  final String fullName;
  final String? nis;
  final String? classroomName;
  final bool faceEnrolled;

  factory RosterEntry.fromJson(Map<String, dynamic> j) => RosterEntry(
        studentId: j['student_id'] as String,
        fullName: j['full_name'] as String? ?? '-',
        nis: j['nis'] as String?,
        classroomName: j['classroom_name'] as String?,
        faceEnrolled: j['face_enrolled'] as bool? ?? false,
      );
}

/// Ringkasan absensi untuk layar monitoring guru / kepala sekolah.
class AttendanceSummary {
  const AttendanceSummary({
    required this.totalStudents,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.alfa,
    required this.belumAbsen,
  });

  final int totalStudents;
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int alfa;
  final int belumAbsen;

  int get hadirTotal => hadir + terlambat;

  double get rate =>
      totalStudents == 0 ? 0 : (hadirTotal / totalStudents) * 100;

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) =>
      AttendanceSummary(
        totalStudents: (j['total_students'] as num?)?.toInt() ?? 0,
        hadir: (j['hadir'] as num?)?.toInt() ?? 0,
        terlambat: (j['terlambat'] as num?)?.toInt() ?? 0,
        izin: (j['izin'] as num?)?.toInt() ?? 0,
        sakit: (j['sakit'] as num?)?.toInt() ?? 0,
        alfa: (j['alfa'] as num?)?.toInt() ?? 0,
        belumAbsen: (j['belum_absen'] as num?)?.toInt() ?? 0,
      );
}

class AttendanceRow {
  const AttendanceRow({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentNis,
    this.classroomName,
    this.checkIn,
    this.checkOut,
    required this.status,
    required this.lateMinutes,
  });

  /// Id baris absensi.
  final String id;

  /// Id siswa — inilah yang dipakai endpoint koreksi, bukan [id].
  final String studentId;

  final String studentName;
  final String? studentNis;
  final String? classroomName;
  final String? checkIn;
  final String? checkOut;
  final String status;
  final int lateMinutes;

  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
        id: j['id'] as String,
        studentId: j['student_id'] as String,
        studentName: j['student_name'] as String? ?? '-',
        studentNis: j['student_nis'] as String?,
        classroomName: j['classroom_name'] as String?,
        checkIn: RecognizeResult._hhmm(j['check_in_at'] as String?),
        checkOut: RecognizeResult._hhmm(j['check_out_at'] as String?),
        status: j['status'] as String? ?? 'alfa',
        lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
      );

  String get statusLabel => switch (status) {
        'hadir' => 'Hadir',
        'terlambat' => 'Terlambat',
        'izin' => 'Izin',
        'sakit' => 'Sakit',
        'alfa' => 'Tanpa Keterangan',
        'dispensasi' => 'Dispensasi',
        _ => status,
      };
}

/// Siswa yang tertaut ke sebuah akun Jargon GO.
///
/// Untuk akun siswa berisi satu entri (dirinya); untuk orang tua berisi
/// anak-anaknya, yang bisa berada di sekolah berbeda.
class LinkedStudent {
  const LinkedStudent({
    required this.id,
    required this.fullName,
    this.nisn,
    this.nis,
    required this.schoolId,
    required this.schoolName,
    this.classroomName,
    required this.relation,
  });

  final String id;
  final String fullName;
  final String? nisn;
  final String? nis;
  final String schoolId;
  final String schoolName;
  final String? classroomName;

  /// `diri_sendiri`, `ayah`, `ibu`, atau `wali`.
  final String relation;

  factory LinkedStudent.fromJson(Map<String, dynamic> j) => LinkedStudent(
        id: j['id'] as String,
        fullName: j['full_name'] as String? ?? '-',
        nisn: j['nisn'] as String?,
        nis: j['nis'] as String?,
        schoolId: j['school_id'] as String? ?? '',
        schoolName: j['school_name'] as String? ?? '-',
        classroomName: j['classroom_name'] as String?,
        relation: j['relation'] as String? ?? 'wali',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'nisn': nisn,
        'nis': nis,
        'school_id': schoolId,
        'school_name': schoolName,
        'classroom_name': classroomName,
        'relation': relation,
      };
}

/// Profil pengguna Jargon GO.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.identityNumber,
    this.identityType,
    this.schoolId,
    this.schoolName,
    required this.roles,
    required this.roleLabel,
    required this.permissions,
    required this.students,
    required this.mustChangePassword,
  });

  final String id;
  final String name;
  final String username;

  /// NIK (16 digit) atau NISN (10 digit).
  final String? identityNumber;
  final String? identityType;

  final String? schoolId;
  final String? schoolName;
  final List<String> roles;

  /// Label peran dari server, bukan dipetakan di aplikasi: menambah peran
  /// baru tidak boleh menuntut rilis aplikasi baru.
  final String roleLabel;

  final List<String> permissions;
  final List<LinkedStudent> students;
  final bool mustChangePassword;

  bool can(String permission) =>
      roles.contains('superadmin') || permissions.contains(permission);

  bool get isStudent => roles.contains('siswa');
  bool get isParent => roles.contains('orang_tua');

  /// Akun yang cakupannya dibatasi pada siswa tertentu.
  bool get isStudentScoped => isStudent || isParent;

  String get identityLabel =>
      identityType == 'nisn' ? 'NISN' : 'NIK';

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String? ?? '-',
        username: j['username'] as String? ?? '-',
        identityNumber: j['identity_number'] as String?,
        identityType: j['identity_type'] as String?,
        schoolId: j['school_id'] as String?,
        schoolName: j['school_name'] as String?,
        roles: (j['roles'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        roleLabel: j['role_label'] as String? ?? 'Pengguna',
        permissions: (j['permissions'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        students: (j['students'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LinkedStudent.fromJson)
            .toList(),
        mustChangePassword: j['must_change_password'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'identity_number': identityNumber,
        'identity_type': identityType,
        'school_id': schoolId,
        'school_name': schoolName,
        'roles': roles,
        'role_label': roleLabel,
        'permissions': permissions,
        'students': students.map((s) => s.toJson()).toList(),
        'must_change_password': mustChangePassword,
      };
}
