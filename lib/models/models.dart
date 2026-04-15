// ═══════════════════════════════════════════════════════════════════
// lib/models/congress_user.dart
// ═══════════════════════════════════════════════════════════════════
class CongressUser {
  final String id;
  final String role;
  final String status;
  final String firstName;
  final String lastName;
  final String? specialty;
  final String? institution;
  final String? country;
  final String? phone;
  final String? phoneCountryCode;
  final String? email;
  final String? avatarUrl;
  final String? qrToken;
  final String? networkingToken;
  final String? adminNotes;
  final DateTime? arrivedAt;
  final bool emailVerified;
  final bool profileComplete;
  final String? googleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CongressUser({
    required this.id,
    required this.role,
    required this.status,
    required this.firstName,
    required this.lastName,
    this.specialty,
    this.institution,
    this.country,
    this.phone,
    this.phoneCountryCode,
    this.email,
    this.avatarUrl,
    this.qrToken,
    this.networkingToken,
    this.adminNotes,
    this.arrivedAt,
    this.emailVerified = false,
    this.profileComplete = false,
    this.googleId,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Computed ──
  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ""}${lastName.isNotEmpty ? lastName[0] : ""}'.toUpperCase();

  bool get isValidated    => status == 'validated';
  bool get isPending      => status == 'pending';
  bool get isBanned       => status == 'banned';
  bool get isReserved     => status == 'reserved';
  bool get hasArrived     => arrivedAt != null;
  bool get isAdmin        => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin   => role == 'super_admin';
  bool get isModerator    => role == 'moderator';
  bool get isReceptionist => role == 'receptionist';
  bool get isGuest        => role == 'guest';
  bool get needsProfile   => !profileComplete;

  String get displayPhone {
    if (phone == null) return '';
    if (phoneCountryCode != null) return '$phoneCountryCode $phone';
    return phone!;
  }

  CongressUser copyWith({
    String? role, String? status, String? firstName, String? lastName,
    String? specialty, String? institution, String? country,
    String? phone, String? phoneCountryCode, String? avatarUrl,
    String? qrToken, String? networkingToken, String? adminNotes,
    DateTime? arrivedAt, bool? emailVerified, bool? profileComplete,
  }) {
    return CongressUser(
      id: id, email: email, googleId: googleId,
      createdAt: createdAt, updatedAt: DateTime.now(),
      role:              role              ?? this.role,
      status:            status            ?? this.status,
      firstName:         firstName         ?? this.firstName,
      lastName:          lastName          ?? this.lastName,
      specialty:         specialty         ?? this.specialty,
      institution:       institution       ?? this.institution,
      country:           country           ?? this.country,
      phone:             phone             ?? this.phone,
      phoneCountryCode:  phoneCountryCode  ?? this.phoneCountryCode,
      avatarUrl:         avatarUrl         ?? this.avatarUrl,
      qrToken:           qrToken           ?? this.qrToken,
      networkingToken:   networkingToken   ?? this.networkingToken,
      adminNotes:        adminNotes        ?? this.adminNotes,
      arrivedAt:         arrivedAt         ?? this.arrivedAt,
      emailVerified:     emailVerified     ?? this.emailVerified,
      profileComplete:   profileComplete   ?? this.profileComplete,
    );
  }

  factory CongressUser.fromJson(Map<String, dynamic> j) => CongressUser(
    id:               j['id'] as String,
    role:             (j['role'] as String?) ?? 'guest',
    status:           (j['status'] as String?) ?? 'pending',
    firstName:        (j['first_name'] as String?) ?? '',
    lastName:         (j['last_name'] as String?) ?? '',
    specialty:        j['specialty'] as String?,
    institution:      j['institution'] as String?,
    country:          j['country'] as String?,
    phone:            j['phone'] as String?,
    phoneCountryCode: j['phone_country_code'] as String?,
    email:            j['email'] as String?,
    avatarUrl:        j['avatar_url'] as String?,
    qrToken:          j['qr_token'] as String?,
    networkingToken:  j['networking_token'] as String?,
    adminNotes:       j['admin_notes'] as String?,
    arrivedAt:        j['arrived_at'] != null
        ? DateTime.parse(j['arrived_at'] as String) : null,
    emailVerified:    (j['email_verified'] as bool?) ?? false,
    profileComplete:  (j['profile_complete'] as bool?) ?? false,
    googleId:         j['google_id'] as String?,
    createdAt:        DateTime.parse(j['created_at'] as String),
    updatedAt:        DateTime.parse(j['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'first_name':         firstName,
    'last_name':          lastName,
    'specialty':          specialty,
    'institution':        institution,
    'country':            country,
    'phone':              phone,
    'phone_country_code': phoneCountryCode,
    'profile_complete':   profileComplete,
  };
}

// ═══════════════════════════════════════════════════════════════════
// lib/models/congress_session.dart
// ═══════════════════════════════════════════════════════════════════
class CongressSession {
  final int id;
  final DateTime date;
  final String startTime;
  final String? endTime;
  final String title;
  final String? speakerName;
  final String? speakerCountry;
  final int sessionNumber;
  final String type; // talk|symposium|break|workshop|ceremony
  final String? hall;
  final bool isZoom;
  final bool qaOpen;
  final bool feedbackOpen;
  final String? moderatorId;

  const CongressSession({
    required this.id,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.title,
    this.speakerName,
    this.speakerCountry,
    required this.sessionNumber,
    required this.type,
    this.hall,
    this.isZoom = false,
    this.qaOpen = false,
    this.feedbackOpen = false,
    this.moderatorId,
  });

  DateTime get dateTime {
    final parts = startTime.replaceAll('h', ':').split(':');
    return DateTime(
      date.year, date.month, date.day,
      int.parse(parts[0]),
      int.parse(parts.length > 1 ? parts[1] : '00'),
    );
  }

  bool get isBreak     => type == 'break';
  bool get isCeremony  => type == 'ceremony';
  bool get isSymposium => type == 'symposium';
  bool get isWorkshop  => type == 'workshop';
  bool get isTalk      => type == 'talk';

  factory CongressSession.fromJson(Map<String, dynamic> j) => CongressSession(
    id:            j['id'] as int,
    date:          DateTime.parse(j['date'] as String),
    startTime:     j['start_time'] as String,
    endTime:       j['end_time'] as String?,
    title:         j['title'] as String,
    speakerName:   j['speaker_name'] as String?,
    speakerCountry:j['speaker_country'] as String?,
    sessionNumber: (j['session_number'] as int?) ?? 0,
    type:          (j['type'] as String?) ?? 'talk',
    hall:          j['hall'] as String?,
    isZoom:        (j['is_zoom'] as bool?) ?? false,
    qaOpen:        (j['qa_open'] as bool?) ?? false,
    feedbackOpen:  (j['feedback_open'] as bool?) ?? false,
    moderatorId:   j['moderator_id'] as String?,
  );
}

// ═══════════════════════════════════════════════════════════════════
// lib/models/congress_question.dart
// ═══════════════════════════════════════════════════════════════════
class CongressQuestion {
  final int id;
  final int sessionId;
  final String userId;
  final String text;
  final bool isAnonymous;
  final String status; // pending|pinned|answered|rejected
  final int votesCount;
  final String? authorName;
  final String? authorCountry;
  final DateTime createdAt;
  final bool hasVoted; // current user voted?

  const CongressQuestion({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.text,
    this.isAnonymous = false,
    this.status = 'pending',
    this.votesCount = 0,
    this.authorName,
    this.authorCountry,
    required this.createdAt,
    this.hasVoted = false,
  });

  bool get isPinned   => status == 'pinned';
  bool get isAnswered => status == 'answered';
  bool get isRejected => status == 'rejected';
  String get displayAuthor => isAnonymous ? 'Anonyme' : (authorName ?? 'Participant');

  CongressQuestion copyWith({int? votesCount, bool? hasVoted, String? status}) {
    return CongressQuestion(
      id: id, sessionId: sessionId, userId: userId, text: text,
      isAnonymous: isAnonymous, createdAt: createdAt,
      authorName: authorName, authorCountry: authorCountry,
      votesCount: votesCount ?? this.votesCount,
      hasVoted:   hasVoted   ?? this.hasVoted,
      status:     status     ?? this.status,
    );
  }

  factory CongressQuestion.fromJson(Map<String, dynamic> j) => CongressQuestion(
    id:            j['id'] as int,
    sessionId:     j['session_id'] as int,
    userId:        j['user_id'] as String,
    text:          j['text'] as String,
    isAnonymous:   (j['is_anonymous'] as bool?) ?? false,
    status:        (j['status'] as String?) ?? 'pending',
    votesCount:    (j['votes_count'] as int?) ?? 0,
    authorName:    j['author_name'] as String?,
    authorCountry: j['author_country'] as String?,
    createdAt:     DateTime.parse(j['created_at'] as String),
    hasVoted:      (j['has_voted'] as bool?) ?? false,
  );
}

// ═══════════════════════════════════════════════════════════════════
// lib/models/congress_notification.dart
// ═══════════════════════════════════════════════════════════════════
class CongressNotification {
  final int id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime createdAt;

  const CongressNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    required this.createdAt,
  });

  factory CongressNotification.fromJson(Map<String, dynamic> j) =>
      CongressNotification(
        id:        j['id'] as int,
        userId:    j['user_id'] as String,
        title:     j['title'] as String,
        body:      j['body'] as String,
        type:      j['type'] as String,
        read:      (j['read'] as bool?) ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ═══════════════════════════════════════════════════════════════════
// lib/models/congress_connection.dart
// ═══════════════════════════════════════════════════════════════════
class CongressConnection {
  final int id;
  final String requesterId;
  final String targetId;
  final String status; // pending|accepted
  final CongressUser? targetUser;
  final CongressUser? requesterUser;
  final DateTime createdAt;

  const CongressConnection({
    required this.id,
    required this.requesterId,
    required this.targetId,
    required this.status,
    this.targetUser,
    this.requesterUser,
    required this.createdAt,
  });

  factory CongressConnection.fromJson(Map<String, dynamic> j) =>
      CongressConnection(
        id:          j['id'] as int,
        requesterId: j['requester_id'] as String,
        targetId:    j['target_id'] as String,
        status:      (j['status'] as String?) ?? 'pending',
        createdAt:   DateTime.parse(j['created_at'] as String),
      );
}

// ═══════════════════════════════════════════════════════════════════
// lib/models/session_feedback.dart
// ═══════════════════════════════════════════════════════════════════
class SessionFeedback {
  final int sessionId;
  final String userId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const SessionFeedback({
    required this.sessionId,
    required this.userId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory SessionFeedback.fromJson(Map<String, dynamic> j) => SessionFeedback(
    sessionId: j['session_id'] as int,
    userId:    j['user_id'] as String,
    rating:    j['rating'] as int,
    comment:   j['comment'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}
