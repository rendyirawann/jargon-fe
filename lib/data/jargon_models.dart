/// Model untuk fitur Super App Jargon GO: beranda, Panic Button, dan
/// Pemberkasan.
///
/// Model absensi & kios tetap di `models.dart`.
library;

// =====================================================================
// Beranda
// =====================================================================

class HomeSummary {
  const HomeSummary({
    required this.greeting,
    required this.roleLabel,
    required this.students,
    this.school,
    required this.panicUpdates,
    required this.documentActions,
    required this.availableMenus,
  });

  final String greeting;
  final String roleLabel;
  final List<StudentTodayCard> students;
  final SchoolTodayCard? school;

  /// Jumlah pengaduan milik sendiri yang statusnya berubah.
  final int panicUpdates;

  /// Pengajuan berkas yang menunggu tindakan pengguna.
  final int documentActions;

  /// Menu yang boleh ditampilkan, ditentukan server dari izin akun.
  ///
  /// Aplikasi TIDAK menyimpulkan sendiri dari peran: menambah peran baru di
  /// dashboard tidak boleh menuntut rilis aplikasi baru.
  final List<String> availableMenus;

  bool hasMenu(String key) => availableMenus.contains(key);

  factory HomeSummary.fromJson(Map<String, dynamic> j) => HomeSummary(
        greeting: j['greeting'] as String? ?? 'Selamat datang',
        roleLabel: j['role_label'] as String? ?? 'Pengguna',
        students: (j['students'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StudentTodayCard.fromJson)
            .toList(),
        school: j['school'] is Map<String, dynamic>
            ? SchoolTodayCard.fromJson(j['school'] as Map<String, dynamic>)
            : null,
        panicUpdates: (j['panic_updates'] as num?)?.toInt() ?? 0,
        documentActions: (j['document_actions'] as num?)?.toInt() ?? 0,
        availableMenus: (j['available_menus'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class StudentTodayCard {
  const StudentTodayCard({
    required this.studentId,
    required this.fullName,
    this.classroomName,
    required this.schoolName,
    required this.relation,
    required this.todayStatus,
    this.checkInTime,
    this.checkOutTime,
    required this.lateMinutes,
    required this.monthPresent,
    required this.monthLate,
    required this.monthAbsent,
  });

  final String studentId;
  final String fullName;
  final String? classroomName;
  final String schoolName;

  /// `diri_sendiri` untuk akun siswa; `ayah`/`ibu`/`wali` untuk orang tua.
  final String relation;

  /// `hadir`, `terlambat`, ..., atau `belum_absen` bila belum discan sama
  /// sekali — berbeda dari `alfa` yang sudah ditetapkan sistem.
  final String todayStatus;
  final String? checkInTime;
  final String? checkOutTime;
  final int lateMinutes;

  final int monthPresent;
  final int monthLate;
  final int monthAbsent;

  bool get isSelf => relation == 'diri_sendiri';

  factory StudentTodayCard.fromJson(Map<String, dynamic> j) => StudentTodayCard(
        studentId: j['student_id'] as String,
        fullName: j['full_name'] as String? ?? '-',
        classroomName: j['classroom_name'] as String?,
        schoolName: j['school_name'] as String? ?? '-',
        relation: j['relation'] as String? ?? 'diri_sendiri',
        todayStatus: j['today_status'] as String? ?? 'belum_absen',
        checkInTime: j['check_in_time'] as String?,
        checkOutTime: j['check_out_time'] as String?,
        lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
        monthPresent: (j['month_present'] as num?)?.toInt() ?? 0,
        monthLate: (j['month_late'] as num?)?.toInt() ?? 0,
        monthAbsent: (j['month_absent'] as num?)?.toInt() ?? 0,
      );
}

class SchoolTodayCard {
  const SchoolTodayCard({
    required this.schoolId,
    required this.schoolName,
    required this.totalStudents,
    required this.hadir,
    required this.terlambat,
    required this.belumAbsen,
    required this.rate,
  });

  final String schoolId;
  final String schoolName;
  final int totalStudents;
  final int hadir;
  final int terlambat;
  final int belumAbsen;
  final double rate;

  factory SchoolTodayCard.fromJson(Map<String, dynamic> j) => SchoolTodayCard(
        schoolId: j['school_id'] as String,
        schoolName: j['school_name'] as String? ?? '-',
        totalStudents: (j['total_students'] as num?)?.toInt() ?? 0,
        hadir: (j['hadir'] as num?)?.toInt() ?? 0,
        terlambat: (j['terlambat'] as num?)?.toInt() ?? 0,
        belumAbsen: (j['belum_absen'] as num?)?.toInt() ?? 0,
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
      );
}

// =====================================================================
// Panic Button
// =====================================================================

class PanicCategory {
  const PanicCategory({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.icon,
    required this.defaultSeverity,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? icon;
  final String defaultSeverity;

  factory PanicCategory.fromJson(Map<String, dynamic> j) => PanicCategory(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '-',
        description: j['description'] as String?,
        icon: j['icon'] as String?,
        defaultSeverity: j['default_severity'] as String? ?? 'sedang',
      );
}

class PanicReport {
  const PanicReport({
    required this.id,
    required this.createdAt,
    required this.categoryCode,
    required this.categoryName,
    required this.anonymousHandle,
    required this.authorRole,
    required this.schoolLabel,
    required this.title,
    required this.body,
    required this.severity,
    required this.status,
    required this.supportCount,
    required this.commentCount,
    required this.isMine,
    required this.isSupported,
    required this.media,
    this.handledAt,
    this.resolvedAt,
  });

  final String id;
  final DateTime createdAt;
  final String categoryCode;
  final String categoryName;

  /// Nama tampilan anonim, mis. `Siswa#7K4M`.
  final String anonymousHandle;
  final String authorRole;

  /// Nama sekolah. Untuk pengguna biasa nilainya sudah disamarkan server
  /// menjadi bentuk seperti "SMA di Medan".
  final String schoolLabel;

  final String title;
  final String body;
  final String severity;
  final String status;
  final int supportCount;
  final int commentCount;
  final bool isMine;
  final bool isSupported;
  final List<String> media;
  final DateTime? handledAt;
  final DateTime? resolvedAt;

  bool get isHandled => handledAt != null;
  bool get isResolved => resolvedAt != null;

  String get statusLabel => switch (status) {
        'baru' => 'Menunggu Diproses',
        'diverifikasi' => 'Sudah Diverifikasi',
        'ditindaklanjuti' => 'Sedang Ditindaklanjuti',
        'selesai' => 'Selesai',
        'ditolak' => 'Ditolak',
        _ => status,
      };

  factory PanicReport.fromJson(Map<String, dynamic> j) => PanicReport(
        id: j['id'] as String,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        categoryCode: j['category_code'] as String? ?? '',
        categoryName: j['category_name'] as String? ?? '-',
        anonymousHandle: j['anonymous_handle'] as String? ?? 'Anonim',
        authorRole: j['author_role'] as String? ?? 'warga',
        schoolLabel: j['school_label'] as String? ?? '-',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        severity: j['severity'] as String? ?? 'sedang',
        status: j['status'] as String? ?? 'baru',
        supportCount: (j['support_count'] as num?)?.toInt() ?? 0,
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        isMine: j['is_mine'] as bool? ?? false,
        isSupported: j['is_supported'] as bool? ?? false,
        media: (j['media'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        handledAt: DateTime.tryParse(j['handled_at'] as String? ?? '')?.toLocal(),
        resolvedAt: DateTime.tryParse(j['resolved_at'] as String? ?? '')?.toLocal(),
      );
}

class PanicReportDetail {
  const PanicReportDetail({
    required this.report,
    required this.timeline,
    required this.comments,
    this.resolution,
    required this.moderationStatus,
    this.moderationNote,
  });

  final PanicReport report;
  final List<PanicTimelineEntry> timeline;
  final List<PanicComment> comments;
  final String? resolution;
  final String moderationStatus;
  final String? moderationNote;

  /// `true` bila laporan masih menunggu diperiksa petugas sebelum tampil.
  bool get isPendingModeration => moderationStatus == 'pending';

  factory PanicReportDetail.fromJson(Map<String, dynamic> j) => PanicReportDetail(
        report: PanicReport.fromJson(j),
        timeline: (j['timeline'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PanicTimelineEntry.fromJson)
            .toList(),
        comments: (j['comments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PanicComment.fromJson)
            .toList(),
        resolution: j['resolution'] as String?,
        moderationStatus: j['moderation_status'] as String? ?? 'approved',
        moderationNote: j['moderation_note'] as String?,
      );
}

class PanicTimelineEntry {
  const PanicTimelineEntry({
    required this.status,
    this.note,
    this.actorLabel,
    required this.createdAt,
  });

  final String status;
  final String? note;
  final String? actorLabel;
  final DateTime createdAt;

  factory PanicTimelineEntry.fromJson(Map<String, dynamic> j) =>
      PanicTimelineEntry(
        status: j['status'] as String? ?? '',
        note: j['note'] as String?,
        actorLabel: j['actor_label'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class PanicComment {
  const PanicComment({
    required this.id,
    this.anonymousHandle,
    required this.isOfficial,
    this.officialName,
    this.officialTitle,
    required this.body,
    required this.isMine,
    required this.createdAt,
  });

  final String id;

  /// `null` untuk komentar resmi — komentar resmi justru menampilkan nama
  /// petugas supaya pelapor tahu laporannya ditangani pihak berwenang.
  final String? anonymousHandle;
  final bool isOfficial;
  final String? officialName;
  final String? officialTitle;
  final String body;
  final bool isMine;
  final DateTime createdAt;

  String get displayName => isOfficial
      ? (officialName ?? 'Petugas')
      : (anonymousHandle ?? 'Anonim');

  factory PanicComment.fromJson(Map<String, dynamic> j) => PanicComment(
        id: j['id'] as String,
        anonymousHandle: j['anonymous_handle'] as String?,
        isOfficial: j['is_official'] as bool? ?? false,
        officialName: j['official_name'] as String?,
        officialTitle: j['official_title'] as String?,
        body: j['body'] as String? ?? '',
        isMine: j['is_mine'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

// =====================================================================
// Pemberkasan
// =====================================================================

class DocumentType {
  const DocumentType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.purpose,
    required this.isRequired,
    required this.maxBytes,
    required this.allowedMime,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String purpose;
  final bool isRequired;
  final int maxBytes;
  final List<String> allowedMime;

  factory DocumentType.fromJson(Map<String, dynamic> j) => DocumentType(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '-',
        description: j['description'] as String?,
        purpose: j['purpose'] as String? ?? 'umum',
        isRequired: j['is_required'] as bool? ?? false,
        maxBytes: (j['max_bytes'] as num?)?.toInt() ?? 5242880,
        allowedMime: (j['allowed_mime'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class Submission {
  const Submission({
    required this.id,
    required this.ownerName,
    this.schoolName,
    required this.purpose,
    this.period,
    required this.title,
    required this.status,
    required this.fileCount,
    required this.approvedFileCount,
    required this.rejectedFileCount,
    this.submittedAt,
    this.reviewedAt,
    required this.createdAt,
  });

  final String id;
  final String ownerName;
  final String? schoolName;
  final String purpose;
  final String? period;
  final String title;
  final String status;
  final int fileCount;
  final int approvedFileCount;
  final int rejectedFileCount;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  bool get isEditable => status == 'draft' || status == 'revisi';

  String get statusLabel => switch (status) {
        'draft' => 'Draft',
        'diajukan' => 'Menunggu Diperiksa',
        'diperiksa' => 'Sedang Diperiksa',
        'revisi' => 'Perlu Perbaikan',
        'disetujui' => 'Disetujui',
        'ditolak' => 'Ditolak',
        _ => status,
      };

  static String purposeLabel(String purpose) => switch (purpose) {
        'kenaikan_pangkat' => 'Kenaikan Pangkat',
        'sertifikasi' => 'Sertifikasi',
        'tunjangan' => 'Tunjangan',
        'mutasi' => 'Mutasi',
        'pensiun' => 'Pensiun',
        _ => 'Umum',
      };

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id'] as String,
        ownerName: j['owner_name'] as String? ?? '-',
        schoolName: j['school_name'] as String?,
        purpose: j['purpose'] as String? ?? 'umum',
        period: j['period'] as String?,
        title: j['title'] as String? ?? '-',
        status: j['status'] as String? ?? 'draft',
        fileCount: (j['file_count'] as num?)?.toInt() ?? 0,
        approvedFileCount: (j['approved_file_count'] as num?)?.toInt() ?? 0,
        rejectedFileCount: (j['rejected_file_count'] as num?)?.toInt() ?? 0,
        submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? '')?.toLocal(),
        reviewedAt: DateTime.tryParse(j['reviewed_at'] as String? ?? '')?.toLocal(),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class SubmissionDetail {
  const SubmissionDetail({
    required this.submission,
    this.note,
    this.reviewNote,
    this.reviewerName,
    required this.files,
    required this.checklist,
    required this.timeline,
    required this.isEditable,
  });

  final Submission submission;
  final String? note;
  final String? reviewNote;
  final String? reviewerName;
  final List<SubmissionFile> files;
  final List<ChecklistItem> checklist;
  final List<SubmissionEvent> timeline;
  final bool isEditable;

  /// Dokumen wajib yang belum diunggah — penentu apakah tombol Ajukan aktif.
  List<ChecklistItem> get missingRequired =>
      checklist.where((c) => c.isRequired && !c.uploaded).toList();

  bool get canSubmit => isEditable && missingRequired.isEmpty;

  factory SubmissionDetail.fromJson(Map<String, dynamic> j) => SubmissionDetail(
        submission: Submission.fromJson(j),
        note: j['note'] as String?,
        reviewNote: j['review_note'] as String?,
        reviewerName: j['reviewer_name'] as String?,
        files: (j['files'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SubmissionFile.fromJson)
            .toList(),
        checklist: (j['checklist'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChecklistItem.fromJson)
            .toList(),
        timeline: (j['timeline'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SubmissionEvent.fromJson)
            .toList(),
        isEditable: j['is_editable'] as bool? ?? false,
      );
}

class SubmissionFile {
  const SubmissionFile({
    required this.id,
    this.documentTypeId,
    this.documentTypeName,
    required this.originalName,
    required this.mimeType,
    required this.bytes,
    required this.status,
    this.rejectReason,
    required this.fileUrl,
  });

  final String id;
  final String? documentTypeId;
  final String? documentTypeName;
  final String originalName;
  final String mimeType;
  final int bytes;
  final String status;
  final String? rejectReason;
  final String fileUrl;

  String get sizeLabel => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';

  factory SubmissionFile.fromJson(Map<String, dynamic> j) => SubmissionFile(
        id: j['id'] as String,
        documentTypeId: j['document_type_id'] as String?,
        documentTypeName: j['document_type_name'] as String?,
        originalName: j['original_name'] as String? ?? '-',
        mimeType: j['mime_type'] as String? ?? '',
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'menunggu',
        rejectReason: j['reject_reason'] as String?,
        fileUrl: j['file_url'] as String? ?? '',
      );
}

class ChecklistItem {
  const ChecklistItem({
    required this.documentTypeId,
    required this.code,
    required this.name,
    this.description,
    required this.isRequired,
    required this.uploaded,
    this.status,
    this.rejectReason,
  });

  final String documentTypeId;
  final String code;
  final String name;
  final String? description;
  final bool isRequired;
  final bool uploaded;
  final String? status;
  final String? rejectReason;

  bool get isRejected => status == 'ditolak';
  bool get isApproved => status == 'disetujui';

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        documentTypeId: j['document_type_id'] as String,
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '-',
        description: j['description'] as String?,
        isRequired: j['is_required'] as bool? ?? false,
        uploaded: j['uploaded'] as bool? ?? false,
        status: j['status'] as String?,
        rejectReason: j['reject_reason'] as String?,
      );
}

class SubmissionEvent {
  const SubmissionEvent({
    required this.status,
    this.note,
    this.actorLabel,
    required this.createdAt,
  });

  final String status;
  final String? note;
  final String? actorLabel;
  final DateTime createdAt;

  factory SubmissionEvent.fromJson(Map<String, dynamic> j) => SubmissionEvent(
        status: j['status'] as String? ?? '',
        note: j['note'] as String?,
        actorLabel: j['actor_label'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}
