class StylistAttendancePose {
  const StylistAttendancePose({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class StylistAttendanceAction {
  const StylistAttendanceAction._({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  static const StylistAttendanceAction checkIn = StylistAttendanceAction._(
    id: 'check_in',
    label: 'Check In',
  );

  static const StylistAttendanceAction checkOut = StylistAttendanceAction._(
    id: 'check_out',
    label: 'Check Out',
  );

  static const List<StylistAttendanceAction> values = <StylistAttendanceAction>[
    checkIn,
    checkOut,
  ];

  String get apiValue {
    switch (id) {
      case 'check_out':
        return 'CHECK_OUT';
      case 'check_in':
      default:
        return 'CHECK_IN';
    }
  }

  static StylistAttendanceAction fromId(String? id) {
    return values.firstWhere(
      (action) => action.id == id,
      orElse: () => checkIn,
    );
  }
}

const List<StylistAttendancePose> kStylistAttendanceRequiredPoses =
    <StylistAttendancePose>[
  StylistAttendancePose(
    id: 'front',
    label: 'Front',
    description: 'Look straight into the camera.',
  ),
  StylistAttendancePose(
    id: 'left',
    label: 'Left Side',
    description: 'Turn slightly to your left.',
  ),
  StylistAttendancePose(
    id: 'right',
    label: 'Right Side',
    description: 'Turn slightly to your right.',
  ),
  StylistAttendancePose(
    id: 'up',
    label: 'Up',
    description: 'Lift your chin slightly upward.',
  ),
  StylistAttendancePose(
    id: 'down',
    label: 'Down',
    description: 'Tilt your chin slightly downward.',
  ),
];

class StylistAttendanceEnrollment {
  StylistAttendanceEnrollment({
    required this.userKey,
    required this.branchId,
    required this.imagePaths,
    required this.updatedAtIso,
    this.completedAtIso,
  });

  final String userKey;
  final int branchId;
  final Map<String, String> imagePaths;
  final String updatedAtIso;
  final String? completedAtIso;

  bool get isComplete => kStylistAttendanceRequiredPoses
      .every((pose) => imagePaths[pose.id] != null);

  int get completedCount => imagePaths.length;

  DateTime? get updatedAt => DateTime.tryParse(updatedAtIso);
  DateTime? get completedAt => DateTime.tryParse(completedAtIso ?? '');

  StylistAttendanceEnrollment copyWith({
    Map<String, String>? imagePaths,
    String? updatedAtIso,
    String? completedAtIso,
  }) {
    return StylistAttendanceEnrollment(
      userKey: userKey,
      branchId: branchId,
      imagePaths: imagePaths ?? this.imagePaths,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      completedAtIso: completedAtIso ?? this.completedAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userKey': userKey,
      'branchId': branchId,
      'imagePaths': imagePaths,
      'updatedAtIso': updatedAtIso,
      'completedAtIso': completedAtIso,
    };
  }

  factory StylistAttendanceEnrollment.fromJson(Map<String, dynamic> json) {
    final rawPaths = json['imagePaths'];
    final imagePaths = <String, String>{};
    if (rawPaths is Map) {
      rawPaths.forEach((key, value) {
        if (key != null && value != null) {
          imagePaths[key.toString()] = value.toString();
        }
      });
    }

    return StylistAttendanceEnrollment(
      userKey: (json['userKey'] ?? '').toString(),
      branchId: (json['branchId'] as num?)?.toInt() ?? 0,
      imagePaths: imagePaths,
      updatedAtIso: (json['updatedAtIso'] ?? '').toString(),
      completedAtIso: json['completedAtIso']?.toString(),
    );
  }
}

class StylistAttendanceRecord {
  StylistAttendanceRecord({
    required this.id,
    required this.branchId,
    required this.userKey,
    required this.scanImagePath,
    required this.markedAtIso,
    required this.status,
    required this.attendanceType,
  });

  final String id;
  final int branchId;
  final String userKey;
  final String scanImagePath;
  final String markedAtIso;
  final String status;
  final String attendanceType;

  DateTime? get markedAt => DateTime.tryParse(markedAtIso);
  StylistAttendanceAction get action =>
      StylistAttendanceAction.fromId(attendanceType);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'branchId': branchId,
      'userKey': userKey,
      'scanImagePath': scanImagePath,
      'markedAtIso': markedAtIso,
      'status': status,
      'attendanceType': attendanceType,
    };
  }

  factory StylistAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return StylistAttendanceRecord(
      id: (json['id'] ?? '').toString(),
      branchId: (json['branchId'] as num?)?.toInt() ?? 0,
      userKey: (json['userKey'] ?? '').toString(),
      scanImagePath: (json['scanImagePath'] ?? '').toString(),
      markedAtIso: (json['markedAtIso'] ?? '').toString(),
      status: (json['status'] ?? 'Marked').toString(),
      attendanceType: (json['attendanceType'] ?? 'check_in').toString(),
    );
  }
}

class StylistAttendanceHistoryEntry {
  StylistAttendanceHistoryEntry({
    required this.id,
    required this.branchId,
    required this.userId,
    required this.checkedInAtIso,
    required this.checkedOutAtIso,
    required this.updatedByUserId,
  });

  final int id;
  final int branchId;
  final int userId;
  final String? checkedInAtIso;
  final String? checkedOutAtIso;
  final int? updatedByUserId;

  DateTime? get checkedInAt => DateTime.tryParse(checkedInAtIso ?? '');
  DateTime? get checkedOutAt => DateTime.tryParse(checkedOutAtIso ?? '');

  factory StylistAttendanceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StylistAttendanceHistoryEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      branchId: (json['branchId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      checkedInAtIso: json['checkedInAt']?.toString(),
      checkedOutAtIso: json['checkedOutAt']?.toString(),
      updatedByUserId: (json['updatedByUserId'] as num?)?.toInt() ??
          (json['attendanceUpdatedByUserId'] as num?)?.toInt(),
    );
  }
}
