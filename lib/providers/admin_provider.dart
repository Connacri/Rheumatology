import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════════
// AdminProvider
// ═══════════════════════════════════════════════════════════════════
class AdminProvider extends ChangeNotifier {
  final _sb = Supabase.instance.client;

  List<CongressUser> _allUsers = [];
  bool _loading = false;
  String _statusFilter = 'all';
  String _searchQuery  = '';

  List<CongressUser> get allUsers => _allUsers;
  bool   get loading      => _loading;
  String get statusFilter => _statusFilter;

  // Statistiques dashboard
  int get totalGuests     => _allUsers.length;
  int get pendingCount    => _allUsers.where((u) => u.isPending).length;
  int get validatedCount  => _allUsers.where((u) => u.isValidated).length;
  int get arrivedCount    => _allUsers.where((u) => u.hasArrived).length;
  int get bannedCount     => _allUsers.where((u) => u.isBanned).length;
  int get reservedCount   => _allUsers.where((u) => u.isReserved).length;

  List<CongressUser> get filteredUsers {
    var list = _allUsers;
    if (_statusFilter != 'all') {
      list = list.where((u) => u.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
        u.fullName.toLowerCase().contains(q)     ||
        (u.specialty?.toLowerCase().contains(q)  ?? false) ||
        (u.institution?.toLowerCase().contains(q) ?? false) ||
        (u.country?.toLowerCase().contains(q)    ?? false) ||
        (u.email?.toLowerCase().contains(q)      ?? false)
      ).toList();
    }
    return list;
  }

  void setFilter(String f) { _statusFilter = f; notifyListeners(); }
  void setSearch(String q) { _searchQuery = q;  notifyListeners(); }

  // ── Load ──────────────────────────────────────────────────────────
  Future<void> loadUsers() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _sb
          .from('congress_users')
          .select()
          .eq('role', 'guest')
          .order('created_at', ascending: false);
      _allUsers = (res as List)
          .map((j) => CongressUser.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('AdminProvider.loadUsers error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CongressUser?> getUserById(String userId) async {
    try {
      final res = await _sb
          .from('congress_users')
          .select()
          .eq('id', userId)
          .single();
      return CongressUser.fromJson(res as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  // ── Actions sur les users ─────────────────────────────────────────
  Future<void> validateUser(String userId) async {
    await _sb.from('congress_users')
        .update({'status': 'validated'}).eq('id', userId);
    await loadUsers();
  }

  Future<void> banUser(String userId) async {
    await _sb.from('congress_users')
        .update({'status': 'banned'}).eq('id', userId);
    await loadUsers();
  }

  Future<void> reserveUser(String userId, String notes) async {
    await _sb.from('congress_users').update({
      'status':      'reserved',
      'admin_notes': notes,
    }).eq('id', userId);
    await loadUsers();
  }

  Future<void> resetToPending(String userId) async {
    await _sb.from('congress_users')
        .update({'status': 'pending', 'admin_notes': null}).eq('id', userId);
    await loadUsers();
  }

  // ── Marquer arrivée depuis scan QR ───────────────────────────────
  Future<CongressUser?> markArrivalByQrToken(String qrToken) async {
    try {
      final res = await _sb
          .from('congress_users')
          .update({'arrived_at': DateTime.now().toIso8601String()})
          .eq('qr_token', qrToken)
          .eq('status', 'validated')
          .select()
          .maybeSingle();
      if (res == null) return null;
      return CongressUser.fromJson(res as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  // ── Statistiques par pays ─────────────────────────────────────────
  Map<String, int> get countByCountry {
    final map = <String, int>{};
    for (final u in _allUsers.where((u) => u.isValidated || u.hasArrived)) {
      final c = u.country ?? 'Inconnu';
      map[c] = (map[c] ?? 0) + 1;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ModeratorProvider — Q&A management
// ═══════════════════════════════════════════════════════════════════
class ModeratorProvider extends ChangeNotifier {
  final _sb = Supabase.instance.client;

  CongressSession? _session;
  List<CongressQuestion> _questions = [];
  RealtimeChannel? _qaChannel;
  bool _loading = false;

  CongressSession?       get session   => _session;
  List<CongressQuestion> get questions => _questions;
  bool                   get loading   => _loading;

  List<CongressQuestion> get sortedQuestions {
    final list = [..._questions]
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.votesCount.compareTo(a.votesCount);
      });
    return list;
  }

  int get totalQuestions => _questions.length;
  int get pendingCount   => _questions.where((q) => q.status == 'pending').length;

  // ── Initialiser une session ───────────────────────────────────────
  Future<void> initSession(int sessionId) async {
    _loading = true;
    notifyListeners();
    try {
      // Load session
      final sRes = await _sb
          .from('congress_sessions')
          .select()
          .eq('id', sessionId)
          .single();
      _session = CongressSession.fromJson(sRes as Map<String, dynamic>);

      // Load existing questions
      await _loadQuestions(sessionId);

      // Subscribe realtime
      _subscribeRealtime(sessionId);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadQuestions(int sessionId) async {
    final res = await _sb
        .from('congress_questions')
        .select()
        .eq('session_id', sessionId)
        .neq('status', 'rejected')
        .order('votes_count', ascending: false);
    _questions = (res as List)
        .map((j) => CongressQuestion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  void _subscribeRealtime(int sessionId) {
    _qaChannel?.unsubscribe();
    _qaChannel = _sb
        .channel('qa_moderator_$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'congress_questions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (_) => _loadQuestions(sessionId).then((_) => notifyListeners()),
        )
        .subscribe();
  }

  // ── Actions modérateur ────────────────────────────────────────────
  Future<void> toggleQa(bool open) async {
    if (_session == null) return;
    await _sb.from('congress_sessions')
        .update({'qa_open': open}).eq('id', _session!.id);
    _session = CongressSession(
      id: _session!.id, date: _session!.date, startTime: _session!.startTime,
      endTime: _session!.endTime, title: _session!.title,
      speakerName: _session!.speakerName, speakerCountry: _session!.speakerCountry,
      sessionNumber: _session!.sessionNumber, type: _session!.type,
      hall: _session!.hall, isZoom: _session!.isZoom,
      qaOpen: open, feedbackOpen: _session!.feedbackOpen,
    );
    notifyListeners();
  }

  Future<void> toggleFeedback(bool open) async {
    if (_session == null) return;
    await _sb.from('congress_sessions')
        .update({'feedback_open': open}).eq('id', _session!.id);
    notifyListeners();
  }

  Future<void> pinQuestion(int questionId) async {
    await _sb.from('congress_questions')
        .update({'status': 'pinned'}).eq('id', questionId);
  }

  Future<void> markAnswered(int questionId) async {
    await _sb.from('congress_questions')
        .update({'status': 'answered'}).eq('id', questionId);
  }

  Future<void> rejectQuestion(int questionId) async {
    await _sb.from('congress_questions')
        .update({'status': 'rejected'}).eq('id', questionId);
  }

  @override
  void dispose() {
    _qaChannel?.unsubscribe();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════
// GuestProvider — actions invité (Q&A, networking, feedback)
// ═══════════════════════════════════════════════════════════════════
class GuestProvider extends ChangeNotifier {
  final _sb = Supabase.instance.client;

  CongressSession? _activeSession;
  List<CongressQuestion> _questions = [];
  RealtimeChannel? _channel;
  bool _loading = false;

  CongressSession?       get activeSession => _activeSession;
  List<CongressQuestion> get questions     => _questions;
  bool                   get loading       => _loading;

  List<CongressQuestion> get sortedQuestions {
    return [..._questions]
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.votesCount.compareTo(a.votesCount);
      });
  }

  Future<void> subscribeSession(int sessionId, String currentUserId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _sb
          .from('congress_questions')
          .select()
          .eq('session_id', sessionId)
          .neq('status', 'rejected')
          .order('votes_count', ascending: false);

      _questions = (res as List).map((j) {
        final q = CongressQuestion.fromJson(j as Map<String, dynamic>);
        return q;
      }).toList();

      _channel?.unsubscribe();
      _channel = _sb
          .channel('qa_guest_$sessionId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'congress_questions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_id',
              value: sessionId,
            ),
            callback: (_) async {
              final updated = await _sb
                  .from('congress_questions')
                  .select()
                  .eq('session_id', sessionId)
                  .neq('status', 'rejected')
                  .order('votes_count', ascending: false);
              _questions = (updated as List)
                  .map((j) => CongressQuestion.fromJson(j as Map<String, dynamic>))
                  .toList();
              notifyListeners();
            },
          )
          .subscribe();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> postQuestion({
    required int sessionId,
    required String userId,
    required String text,
    required bool isAnonymous,
    String? authorName,
    String? authorCountry,
  }) async {
    try {
      await _sb.from('congress_questions').insert({
        'session_id':     sessionId,
        'user_id':        userId,
        'text':           text,
        'is_anonymous':   isAnonymous,
        'author_name':    isAnonymous ? null : authorName,
        'author_country': isAnonymous ? null : authorCountry,
      });
      return null;
    } catch (e) { return e.toString(); }
  }

  Future<void> voteQuestion(int questionId, String userId) async {
    try {
      await _sb.from('question_votes').insert({
        'question_id': questionId,
        'user_id':     userId,
      });
    } catch (_) {}
  }

  Future<String?> submitFeedback({
    required int sessionId,
    required String userId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _sb.from('session_feedbacks').upsert({
        'session_id': sessionId,
        'user_id':    userId,
        'rating':     rating,
        'comment':    comment,
      });
      return null;
    } catch (e) { return e.toString(); }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
