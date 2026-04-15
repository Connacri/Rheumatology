// ═══════════════════════════════════════════════════════════════════
// screens/guest/qa_screen.dart
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});
  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  final _sb          = Supabase.instance.client;
  final _questionCtrl= TextEditingController();
  bool _anonymous    = false;
  bool _sending      = false;
  bool _qaOpen       = false;
  CongressSession? _activeSession;
  List<CongressQuestion> _questions = [];
  Set<int> _myVotes   = {};
  RealtimeChannel? _channel;
  int? _sessionId;

  @override
  void initState() {
    super.initState();
    _loadActiveSession();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadActiveSession() async {
    try {
      // Chercher la session avec qa_open = true
      final res = await _sb
          .from('congress_sessions')
          .select()
          .eq('qa_open', true)
          .maybeSingle();

      if (res != null) {
        final session = CongressSession.fromJson(res as Map<String, dynamic>);
        setState(() {
          _activeSession = session;
          _sessionId     = session.id;
          _qaOpen        = true;
        });
        await _loadQuestions(session.id);
        _subscribeRealtime(session.id);
      } else {
        setState(() => _qaOpen = false);
        _subscribeSessionUpdates();
      }
    } catch (e) {
      debugPrint('QaScreen._loadActiveSession error: $e');
    }
  }

  Future<void> _loadQuestions(int sessionId) async {
    final uid = context.read<AuthProvider>().user?.id;
    final res = await _sb
        .from('congress_questions')
        .select()
        .eq('session_id', sessionId)
        .neq('status', 'rejected')
        .order('votes_count', ascending: false);

    // Mes votes
    if (uid != null) {
      final votes = await _sb
          .from('question_votes')
          .select('question_id')
          .eq('user_id', uid);
      _myVotes = (votes as List)
          .map((v) => v['question_id'] as int)
          .toSet();
    }

    setState(() {
      _questions = (res as List)
          .map((j) => CongressQuestion.fromJson(j as Map<String, dynamic>))
          .toList();
    });
  }

  void _subscribeRealtime(int sessionId) {
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
          callback: (_) => _loadQuestions(sessionId),
        )
        .subscribe();
  }

  void _subscribeSessionUpdates() {
    _channel?.unsubscribe();
    _channel = _sb
        .channel('sessions_qa_watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'congress_sessions',
          callback: (payload) {
            final updated = payload.newRecord;
            if (updated['qa_open'] == true) {
              _loadActiveSession();
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendQuestion() async {
    final text = _questionCtrl.text.trim();
    if (text.isEmpty || text.length < 10) {
      _showSnack('Question trop courte (minimum 10 caractères)', error: true);
      return;
    }
    if (_sessionId == null) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      await _sb.from('congress_questions').insert({
        'session_id':     _sessionId,
        'user_id':        user.id,
        'text':           text,
        'is_anonymous':   _anonymous,
        'author_name':    _anonymous ? null : user.fullName,
        'author_country': _anonymous ? null : user.country,
      });
      _questionCtrl.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _vote(CongressQuestion q) async {
    if (_myVotes.contains(q.id)) return;
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;

    setState(() => _myVotes.add(q.id));
    try {
      await _sb.from('question_votes').insert({
        'question_id': q.id,
        'user_id':     uid,
      });
    } catch (_) {
      setState(() => _myVotes.remove(q.id));
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_activeSession?.title ?? 'Q&A Live'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _qaOpen ? AppColors.success.withOpacity(0.15) : Colors.transparent,
              borderRadius: AppRadius.full,
              border: Border.all(
                color: _qaOpen ? AppColors.success : Colors.white30),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _qaOpen ? AppColors.success : Colors.white38,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _qaOpen ? 'OUVERT' : 'FERMÉ',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: _qaOpen ? AppColors.success : Colors.white54,
                  letterSpacing: 1,
                ),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      floatingActionButton: _qaOpen
          ? FloatingActionButton.extended(
              onPressed: _showAskDialog,
              icon: const Icon(Icons.add_comment),
              label: const Text('Poser une question'),
            )
          : null,
      body: _qaOpen ? _buildQuestionsList() : _buildQaClosed(),
    );
  }

  Widget _buildQaClosed() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.navyMid.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    size: 40, color: AppColors.navyMid),
              ),
              const SizedBox(height: 20),
              const Text('Q&A en attente d\'ouverture',
                  style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Le modérateur ouvrira le Q&A pendant la session. '
                'Vous serez notifié dès son ouverture.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const _PulsingDots(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsList() {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Soyez le premier à poser une question !',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAskDialog,
              icon: const Icon(Icons.add),
              label: const Text('Poser une question'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _questions.length,
      itemBuilder: (_, i) {
        final q     = _questions[i];
        final voted = _myVotes.contains(q.id);
        return _GuestQuestionCard(
          question: q,
          rank: i,
          hasVoted: voted,
          onVote: voted ? null : () => _vote(q),
        );
      },
    );
  }

  void _showAskDialog() {
    _questionCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    )),
              ),
              const SizedBox(height: 16),
              const Text('Poser une question', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Session : ${_activeSession?.title ?? ""}',
                style: AppTextStyles.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _questionCtrl,
                maxLines: 4,
                maxLength: 280,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Votre question pour l\'orateur...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Toggle anonyme
              Row(children: [
                Switch(
                  value: _anonymous,
                  onChanged: (v) => setModal(() => _anonymous = v),
                  activeColor: AppColors.navyMid,
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Poser anonymement',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(_anonymous ? 'Votre nom n\'apparaîtra pas'
                      : 'Votre nom sera visible',
                      style: AppTextStyles.labelSmall),
                ]),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _sendQuestion,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: const Text('Envoyer ma question'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestQuestionCard extends StatelessWidget {
  final CongressQuestion question;
  final int rank;
  final bool hasVoted;
  final VoidCallback? onVote;

  const _GuestQuestionCard({
    required this.question,
    required this.rank,
    required this.hasVoted,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final isPinned   = q.isPinned;
    final isAnswered = q.isAnswered;
    final isTop      = rank == 0 && !isPinned;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lg,
          border: Border(
            left: BorderSide(
              color: isPinned ? AppColors.success
                  : isAnswered ? AppColors.info
                  : isTop ? AppColors.navyMid
                  : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges
              if (isPinned || isAnswered || isTop)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(spacing: 6, children: [
                    if (isPinned)
                      _Badge('📌 Épinglée par le modérateur', AppColors.success),
                    if (isAnswered)
                      _Badge('✅ Question posée', AppColors.info),
                    if (isTop)
                      _Badge('🏆 Top question', AppColors.navyMid),
                  ]),
                ),

              // Question
              Text(q.text,
                  style: TextStyle(
                    fontSize: 14, height: 1.5,
                    color: isAnswered ? AppColors.textMuted : AppColors.textPrimary,
                    fontWeight: isPinned ? FontWeight.w600 : FontWeight.normal,
                  )),

              const SizedBox(height: 10),

              // Footer
              Row(children: [
                // Auteur
                if (q.authorCountry != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(q.authorCountry!, style: const TextStyle(fontSize: 13)),
                  ),
                Expanded(
                  child: Text(q.displayAuthor,
                      style: AppTextStyles.bodyMedium),
                ),

                // Bouton vote
                GestureDetector(
                  onTap: onVote,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasVoted
                          ? AppColors.navyMid.withOpacity(0.1)
                          : AppColors.surface,
                      borderRadius: AppRadius.full,
                      border: Border.all(
                        color: hasVoted ? AppColors.navyMid : AppColors.border,
                        width: hasVoted ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 14,
                        color: hasVoted ? AppColors.navyMid : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text('${q.votesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasVoted ? AppColors.navyMid : AppColors.textSecondary,
                          )),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final offset = (i / 3.0);
            final val    = ((_ctrl.value - offset) % 1.0).clamp(0.0, 1.0);
            final scale  = 0.6 + 0.6 * (val < 0.5 ? val * 2 : (1 - val) * 2);
            final opacity = (0.4 + 0.6 * (scale - 0.6) / 0.6).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8 * scale, height: 8 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navyMid.withOpacity(opacity),
              ),
            );
          },
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/guest/networking_screen.dart
// ═══════════════════════════════════════════════════════════════════
class NetworkingScreen extends StatefulWidget {
  const NetworkingScreen({super.key});
  @override
  State<NetworkingScreen> createState() => _NetworkingScreenState();
}

class _NetworkingScreenState extends State<NetworkingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _pending     = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadConnections();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final res = await _sb
          .from('congress_connections')
          .select('*, requester:requester_id(id,first_name,last_name,specialty,institution,country,avatar_url), target:target_id(id,first_name,last_name,specialty,institution,country,avatar_url)')
          .or('requester_id.eq.$uid,target_id.eq.$uid');

      final all = res as List;
      _connections = all
          .where((c) => c['status'] == 'accepted')
          .cast<Map<String, dynamic>>()
          .toList();
      _pending = all
          .where((c) => c['status'] == 'pending' && c['target_id'] == uid)
          .cast<Map<String, dynamic>>()
          .toList();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptConnection(int id) async {
    await _sb.from('congress_connections')
        .update({'status': 'accepted'}).eq('id', id);
    await _loadConnections();
  }

  Future<void> _rejectConnection(int id) async {
    await _sb.from('congress_connections').delete().eq('id', id);
    await _loadConnections();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Mon Réseau'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Connexions (${_connections.length})'),
            Tab(text: 'Demandes (${_pending.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanNetworkingQr,
            tooltip: 'Scanner pour connecter',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildConnectionsList(),
                _buildPendingList(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMyNetworkingQr,
        icon: const Icon(Icons.qr_code_2),
        label: const Text('Mon QR réseau'),
        backgroundColor: AppColors.navyMid,
      ),
    );
  }

  Widget _buildConnectionsList() {
    if (_connections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Aucune connexion pour l\'instant',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            const Text('Scannez le QR networking d\'un participant\npour vous connecter',
                style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _connections.length,
      itemBuilder: (_, i) {
        final conn = _connections[i];
        final uid  = context.read<AuthProvider>().user?.id;
        final other = conn['requester_id'] == uid
            ? conn['target']   as Map<String, dynamic>
            : conn['requester'] as Map<String, dynamic>;
        return _ConnectionCard(user: other);
      },
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) {
      return const Center(
        child: Text('Aucune demande en attente',
            style: AppTextStyles.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pending.length,
      itemBuilder: (_, i) {
        final conn     = _pending[i];
        final requester= conn['requester'] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.navyMid.withOpacity(0.1),
                  backgroundImage: requester['avatar_url'] != null
                      ? NetworkImage(requester['avatar_url']) : null,
                  child: requester['avatar_url'] == null
                      ? Text(
                          '${requester['first_name']?[0] ?? ''}${requester['last_name']?[0] ?? ''}',
                          style: const TextStyle(color: AppColors.navyMid,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${requester['first_name']} ${requester['last_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (requester['specialty'] != null)
                        Text(requester['specialty'],
                            style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: AppColors.success),
                    onPressed: () => _acceptConnection(conn['id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: AppColors.error),
                    onPressed: () => _rejectConnection(conn['id']),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMyNetworkingQr() {
    final user = context.read<AuthProvider>().user;
    if (user?.networkingToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR networking disponible après validation')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mon QR Réseau', style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            const Text('Les autres participants scannent ce QR pour se connecter',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // QR code networking (import qr_flutter)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                user!.networkingToken!.substring(0, 8).toUpperCase(),
                style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 24, fontWeight: FontWeight.w800,
                    color: AppColors.navyMid, letterSpacing: 4),
              ),
              // ← En production : QrImageView(data: user.networkingToken!)
            ),
            const SizedBox(height: 16),
            Text(user.fullName,
                style: AppTextStyles.titleMedium),
            if (user.specialty != null)
              Text(user.specialty!, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  Future<void> _scanNetworkingQr() async {
    // En production: mobile_scanner → récupérer le networking_token
    // puis créer la connexion dans congress_connections
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanner le QR networking d\'un participant')));
  }
}

class _ConnectionCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _ConnectionCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.navyMid.withOpacity(0.1),
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url']) : null,
              child: user['avatar_url'] == null
                  ? Text(
                      '${user['first_name']?[0] ?? ''}${user['last_name']?[0] ?? ''}',
                      style: const TextStyle(color: AppColors.navyMid,
                          fontWeight: FontWeight.bold, fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${user['first_name']} ${user['last_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (user['specialty'] != null)
                    Text(user['specialty'], style: AppTextStyles.bodyMedium),
                  if (user['institution'] != null)
                    Text(user['institution'],
                        style: AppTextStyles.labelSmall,
                        overflow: TextOverflow.ellipsis),
                  if (user['country'] != null)
                    Text('🌍 ${user['country']}',
                        style: const TextStyle(fontSize: 11,
                            color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(Icons.people, color: AppColors.success, size: 20),
                const SizedBox(height: 4),
                const Text('Connecté',
                    style: TextStyle(fontSize: 9, color: AppColors.success,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
