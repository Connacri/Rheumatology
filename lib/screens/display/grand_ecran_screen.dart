import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

enum DisplayMode { combined, pollOnly, qaOnly, sessionInfo }

class GrandEcranScreen extends StatefulWidget {
  final int sessionId;
  const GrandEcranScreen({super.key, required this.sessionId});

  @override
  State<GrandEcranScreen> createState() => _GrandEcranScreenState();
}

class _GrandEcranScreenState extends State<GrandEcranScreen>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  CongressSession? _session;
  List<CongressQuestion> _questions = [];
  Map<String, int> _pollVotes       = {};
  List<Map<String, dynamic>> _reactions = [];
  List<Map<String, dynamic>> _pollOptions = [];

  DisplayMode _mode = DisplayMode.combined;
  bool _pollActive  = true;
  int _timerSecs    = 1800;
  int _liveUsers    = 0;
  int _totalVotes   = 0;
  DateTime _now     = DateTime.now();

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  RealtimeChannel? _qaChannel;
  RealtimeChannel? _sessionChannel;
  Timer? _clockTimer;
  Timer? _timerCountdown;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();

    // Mode paysage forcé pour le grand écran
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initPollOptions();
    _loadSession();
    _subscribeRealtime();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timerSecs > 0) setState(() => _timerSecs--);
    });
  }

  void _initPollOptions() {
    _pollOptions = [
      {'id': 'a', 'label': 'Oui, systématiquement',     'color': 0xFF22C55E},
      {'id': 'b', 'label': 'Oui, selon profil patient', 'color': 0xFF3B82F6},
      {'id': 'c', 'label': 'Non, après bisphosphonates','color': 0xFFF59E0B},
      {'id': 'd', 'label': 'Jamais utilisé',            'color': 0xFFEF4444},
    ];
    _pollVotes = {'a': 42, 'b': 87, 'c': 31, 'd': 8};
    _totalVotes = _pollVotes.values.fold(0, (a, b) => a + b);
  }

  Future<void> _loadSession() async {
    try {
      final res = await _sb.from('congress_sessions')
          .select().eq('id', widget.sessionId).single();
      final session = CongressSession.fromJson(res as Map<String, dynamic>);

      final qRes = await _sb.from('congress_questions')
          .select()
          .eq('session_id', widget.sessionId)
          .neq('status', 'rejected')
          .order('votes_count', ascending: false);

      final users = await _sb.from('congress_users')
          .select('id').eq('status', 'validated');

      if (mounted) setState(() {
        _session    = session;
        _questions  = (qRes as List)
            .map((j) => CongressQuestion.fromJson(j as Map<String, dynamic>))
            .toList();
        _liveUsers  = (users as List).length;
        _pollActive = session.qaOpen;
      });
    } catch (e) {
      debugPrint('GrandEcran._loadSession: $e');
    }
  }

  void _subscribeRealtime() {
    // Questions realtime
    _qaChannel = _sb
        .channel('display_qa_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'congress_questions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: widget.sessionId,
          ),
          callback: (_) => _loadSession(),
        )
        .subscribe();

    // Session updates (qa_open toggle)
    _sessionChannel = _sb
        .channel('display_session_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'congress_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.sessionId,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            if (mounted) setState(() {
              _pollActive = updated['qa_open'] as bool? ?? false;
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulseCtrl.dispose();
    _qaChannel?.unsubscribe();
    _sessionChannel?.unsubscribe();
    _clockTimer?.cancel();
    _timerCountdown?.cancel();
    super.dispose();
  }

  int get _totalVotesComputed =>
      _pollVotes.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      body: Stack(
        children: [
          // ── Background pattern ──
          const _BackgroundPattern(),

          Column(
            children: [
              // ── Top bar ──
              _buildTopBar(),
              // ── Mode switcher ──
              _buildModeSwitcher(),
              // ── Main content ──
              Expanded(child: _buildMainContent()),
              // ── Bottom ticker ──
              _buildBottomTicker(),
            ],
          ),

          // ── Floating reactions ──
          ..._reactions.map((r) => _FloatingReaction(
            emoji: r['emoji'] as String,
            x:     r['x'] as double,
          )),
        ],
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1628).withOpacity(0.95),
        border: const Border(bottom: BorderSide(color: Color(0xFF1E3A5F))),
      ),
      child: Row(
        children: [
          // Session info
          Expanded(
            child: Row(children: [
              if (_session != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A020).withOpacity(0.15),
                    borderRadius: AppRadius.sm,
                    border: Border.all(color: const Color(0xFFE8A020).withOpacity(0.5)),
                  ),
                  child: Text(
                    _session!.type == 'symposium' ? 'SYMPOSIUM'
                        : 'SESSION ${_session!.sessionNumber}',
                    style: const TextStyle(
                      color: Color(0xFFE8A020), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _session!.title,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (_session!.speakerName != null)
                        Text(
                          '${_session!.speakerName} · ${_session!.speakerCountry ?? ''}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ],
            ]),
          ),

          // Timer circulaire
          _CircularTimer(seconds: _timerSecs, total: 1800),
          const SizedBox(width: 20),

          // Stats live
          _LiveStat(value: '$_liveUsers', label: 'En ligne', color: AppColors.success),
          const SizedBox(width: 16),
          _LiveStat(value: '$_totalVotesComputed', label: 'Votes', color: AppColors.accent),
          const SizedBox(width: 16),
          _LiveStat(value: '${_questions.length}', label: 'Questions', color: AppColors.symposium),
        ],
      ),
    );
  }

  // ── Mode Switcher ─────────────────────────────────────────────────
  Widget _buildModeSwitcher() {
    final modes = [
      (DisplayMode.combined,   '⚡ Combiné'),
      (DisplayMode.pollOnly,   '📊 Sondage'),
      (DisplayMode.qaOnly,     '💬 Q&A'),
      (DisplayMode.sessionInfo,'🎤 Session'),
    ];

    return Container(
      color: const Color(0xFF0A1425).withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          ...modes.map((m) {
            final sel = _mode == m.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _mode = m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.navyMid.withOpacity(0.4) : Colors.transparent,
                    borderRadius: AppRadius.full,
                    border: Border.all(
                      color: sel ? AppColors.accent : const Color(0xFF1E3A5F)),
                  ),
                  child: Text(m.$2, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: sel ? AppColors.accentLight : const Color(0xFF475569),
                  )),
                ),
              ),
            );
          }),
          const Spacer(),
          // Toggle poll
          GestureDetector(
            onTap: () => setState(() => _pollActive = !_pollActive),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: (_pollActive ? AppColors.success : AppColors.error)
                    .withOpacity(0.15),
                borderRadius: AppRadius.full,
                border: Border.all(
                  color: (_pollActive ? AppColors.success : AppColors.error)
                      .withOpacity(0.6)),
              ),
              child: Text(
                _pollActive ? '⏸ Fermer sondage' : '▶ Ouvrir sondage',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _pollActive ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Fullscreen hint
          const Icon(Icons.fullscreen, color: Color(0xFF334155), size: 20),
        ],
      ),
    );
  }

  // ── Main content ──────────────────────────────────────────────────
  Widget _buildMainContent() {
    return switch (_mode) {
      DisplayMode.combined    => _buildCombined(),
      DisplayMode.pollOnly    => _buildPollPanel(full: true),
      DisplayMode.qaOnly      => _buildQaPanel(full: true),
      DisplayMode.sessionInfo => _buildSessionInfo(),
    };
  }

  Widget _buildCombined() {
    return Row(
      children: [
        Expanded(child: _buildPollPanel(full: false)),
        Container(width: 1, color: const Color(0xFF1E3A5F)),
        Expanded(child: _buildQaPanel(full: false)),
      ],
    );
  }

  // ── Poll Panel ────────────────────────────────────────────────────
  Widget _buildPollPanel({required bool full}) {
    final total = _totalVotesComputed;
    final ranked = [..._pollOptions]
      ..sort((a, b) => (_pollVotes[b['id']] ?? 0)
          .compareTo(_pollVotes[a['id']] ?? 0));

    return Container(
      color: const Color(0xFF060E1C),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pollActive ? AppColors.success : const Color(0xFF475569),
                  boxShadow: _pollActive ? [BoxShadow(
                    color: AppColors.success.withOpacity(_pulseAnim.value * 0.8),
                    blurRadius: 8, spreadRadius: 2,
                  )] : [],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _pollActive ? 'SONDAGE ACTIF' : 'SONDAGE FERMÉ',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2,
                color: _pollActive ? AppColors.success : const Color(0xFF475569),
              ),
            ),
            const Spacer(),
            Text('$total votes',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
          const SizedBox(height: 14),

          // Question
          const Text(
            'Utilisez-vous le Denosumab en 1ère intention\nchez vos patients ostéoporotiques ?',
            style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Barres
          Expanded(
            child: Column(
              children: ranked.asMap().entries.map((e) {
                final opt   = e.value;
                final votes = _pollVotes[opt['id']] ?? 0;
                final pct   = total == 0 ? 0.0 : votes / total;
                final isWin = e.key == 0;
                final color = Color(opt['color'] as int);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (isWin) const Text('🏆', style: TextStyle(fontSize: 14)),
                          if (isWin) const SizedBox(width: 6),
                          Expanded(
                            child: Text(opt['label'] as String,
                                style: TextStyle(
                                  color: isWin ? Colors.white : const Color(0xFFCBD5E1),
                                  fontSize: full ? 15 : 13,
                                  fontWeight: isWin ? FontWeight.w700 : FontWeight.w500,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(pct * 100).round()}%',
                            style: TextStyle(
                              color: color, fontSize: full ? 22 : 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(
                              height: isWin ? 22 : 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: AppRadius.full,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              height: isWin ? 22 : 16,
                              width: (MediaQuery.of(context).size.width / 2 - 48) * pct,
                              decoration: BoxDecoration(
                                color: color.withOpacity(isWin ? 1.0 : 0.7),
                                borderRadius: AppRadius.full,
                                boxShadow: isWin ? [
                                  BoxShadow(color: color.withOpacity(0.4),
                                      blurRadius: 12),
                                ] : [],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Q&A Panel ─────────────────────────────────────────────────────
  Widget _buildQaPanel({required bool full}) {
    final sorted = [..._questions]
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.votesCount.compareTo(a.votesCount);
      });

    return Container(
      color: const Color(0xFF060E1C),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                  boxShadow: [BoxShadow(
                    color: AppColors.success.withOpacity(_pulseAnim.value * 0.6),
                    blurRadius: 6,
                  )],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('QUESTIONS LIVE',
                style: TextStyle(
                  color: AppColors.success, fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 2,
                )),
            const Spacer(),
            Text('${sorted.length} questions • triées par votes',
                style: const TextStyle(color: Color(0xFF475569), fontSize: 11)),
          ]),
          const SizedBox(height: 12),

          // Questions list
          Expanded(
            child: sorted.isEmpty
                ? const Center(
                    child: Text('En attente des questions...',
                        style: TextStyle(color: Color(0xFF475569), fontSize: 14)))
                : ListView.builder(
                    itemCount: sorted.length.clamp(0, 6),
                    itemBuilder: (_, i) => _DisplayQuestionCard(
                      question: sorted[i],
                      rank: i,
                    ),
                  ),
          ),

          // CTA participants
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1A2E),
              borderRadius: AppRadius.md,
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(children: [
              const Icon(Icons.phone_android, color: Color(0xFF475569), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '📱 Ouvrez l\'app Congress Oran → Programme → Session → Q&A',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Session Info ──────────────────────────────────────────────────
  Widget _buildSessionInfo() {
    if (_session == null) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFF050D1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.primaryHeader,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              _session!.type == 'symposium' ? 'SYMPOSIUM' : 'SESSION ${_session!.sessionNumber}',
              style: const TextStyle(
                color: Color(0xFFE8A020), fontSize: 12,
                fontWeight: FontWeight.w800, letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Text(
                _session!.title,
                style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (_session!.speakerName != null) ...[
              Text(_session!.speakerName!,
                  style: const TextStyle(color: AppColors.accentLight,
                      fontSize: 18, fontWeight: FontWeight.w700)),
              if (_session!.speakerCountry != null)
                Text(_session!.speakerCountry!,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InfoChip('$_liveUsers participants', Icons.people),
                const SizedBox(width: 16),
                _InfoChip(_session!.startTime, Icons.access_time),
                if (_session!.isZoom) ...[
                  const SizedBox(width: 16),
                  _InfoChip('Zoom', Icons.videocam),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Ticker ─────────────────────────────────────────────────
  Widget _buildBottomTicker() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B1628),
            const Color(0xFF1A2A4A),
            const Color(0xFF0B1628),
          ],
        ),
        border: const Border(top: BorderSide(color: Color(0xFF1E3A5F))),
      ),
      child: Row(
        children: [
          // Logo / titre
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              '◆ 14ÈME CONGRÈS RHUMATOLOGIE ORAN',
              style: TextStyle(
                color: Color(0xFFE8A020), fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.5,
              ),
            ),
          ),
          Container(width: 1, height: 20, color: const Color(0xFF1E3A5F)),

          // Ticker text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  '23-25 Avril 2026 • Oran, Algérie   •   '
                  '$_liveUsers participants connectés sur l\'app   •   '
                  '${_questions.length} questions posées   •   '
                  'AAMRO — Association Algérienne des Maladies Rhumatismales d\'Oran',
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 10),
                ),
              ),
            ),
          ),

          Container(width: 1, height: 20, color: const Color(0xFF1E3A5F)),
          // Heure
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Color(0xFF64748B), fontSize: 11,
                fontWeight: FontWeight.w600, fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Display Question Card ─────────────────────────────────────────
class _DisplayQuestionCard extends StatelessWidget {
  final CongressQuestion question;
  final int rank;
  const _DisplayQuestionCard({required this.question, required this.rank});

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: q.isPinned
            ? const Color(0xFF0D3D1F)
            : rank == 0 ? const Color(0xFF0D1E3A) : const Color(0xFF0A1628),
        borderRadius: AppRadius.md,
        border: Border(
          left: BorderSide(
            color: q.isPinned ? AppColors.success
                : rank == 0 ? AppColors.accent : const Color(0xFF1E3A5F),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (q.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('📌 ÉPINGLÉE',
                        style: TextStyle(
                          color: AppColors.success, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5,
                        )),
                  ),
                Text(q.text,
                    style: TextStyle(
                      color: q.isAnswered ? const Color(0xFF64748B) : Colors.white,
                      fontSize: 13, height: 1.4,
                      fontWeight: q.isPinned ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  if (q.authorCountry != null)
                    Text(q.authorCountry!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(q.displayAuthor,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              const Icon(Icons.thumb_up, color: Color(0xFF475569), size: 16),
              const SizedBox(height: 2),
              Text('${q.votesCount}',
                  style: TextStyle(
                    color: q.isPinned ? AppColors.success
                        : rank == 0 ? AppColors.accentLight : const Color(0xFF94A3B8),
                    fontSize: 16, fontWeight: FontWeight.w900,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Circular Timer ───────────────────────────────────────────────
class _CircularTimer extends StatelessWidget {
  final int seconds;
  final int total;
  const _CircularTimer({required this.seconds, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct   = seconds / total;
    final mm    = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss    = (seconds % 60).toString().padLeft(2, '0');
    final color = seconds < 120 ? AppColors.error
        : seconds < 300 ? AppColors.warning : AppColors.success;

    return SizedBox(
      width: 72, height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFF1E3A5F),
            color: color,
            strokeWidth: 4,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$mm:$ss',
                    style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w900,
                    )),
                const Text('restant',
                    style: TextStyle(color: Color(0xFF475569), fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live Stat ────────────────────────────────────────────────────
class _LiveStat extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _LiveStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(
            color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(
            color: Color(0xFF475569), fontSize: 9, letterSpacing: 0.8)),
      ],
    );
  }
}

// ── Info Chip ────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E3A),
        borderRadius: AppRadius.full,
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF475569), size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Color(0xFF94A3B8),
                fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Floating Reaction ────────────────────────────────────────────
class _FloatingReaction extends StatefulWidget {
  final String emoji;
  final double x;
  const _FloatingReaction({required this.emoji, required this.x});
  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _pos;
  late Animation<double>  _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800));
    _pos = Tween<Offset>(
      begin: Offset(widget.x, MediaQuery.of(context).size.height - 100),
      end:   Offset(widget.x, MediaQuery.of(context).size.height - 350),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: _pos.value.dx,
        top:  _pos.value.dy,
        child: Opacity(
          opacity: _opacity.value,
          child: Text(widget.emoji,
              style: const TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}

// ── Background Pattern ────────────────────────────────────────────
class _BackgroundPattern extends StatelessWidget {
  const _BackgroundPattern();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _BgPainter()),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double r = 40; r < 600; r += 50) {
      canvas.drawCircle(Offset(size.width * 0.85, 0), r, p);
    }
    p.color = Colors.white.withOpacity(0.015);
    for (double x = -100; x < size.width + 100; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
