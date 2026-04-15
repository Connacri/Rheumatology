// ═══════════════════════════════════════════════════════════════════
// screens/receptionist/qr_scanner_screen.dart
// ═══════════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _processing = false;
  CongressUser? _lastUser;
  bool? _success;
  Timer? _resetTimer;
  int _scannedToday = 0;

  @override
  void dispose() {
    _controller.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _processing = true);
    await _controller.stop();

    final user = await context.read<AdminProvider>().markArrivalByQrToken(raw);

    setState(() {
      _lastUser = user;
      _success  = user != null;
      if (user != null) _scannedToday++;
    });

    // Vibration feedback
    // HapticFeedback.heavyImpact();

    _resetTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _processing = false;
          _lastUser   = null;
          _success    = null;
        });
        _controller.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1628),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scanner Badge Invité'),
            Text('Arrivées aujourd\'hui : $_scannedToday',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Lampe torche',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Caméra ──
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Overlay sombre ──
          ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: CustomPaint(
              painter: _ScanOverlayPainter(),
              child: const SizedBox.expand(),
            ),
          ),

          // ── Cadre de scan ──
          Center(
            child: _ScanFrame(),
          ),

          // ── Guide texte ──
          Positioned(
            bottom: 120,
            left: 0, right: 0,
            child: Column(
              children: [
                const Text('Pointez vers le QR code du badge',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Le badge doit être validé par l\'administration',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),

          // ── Résultat scan ──
          if (_success != null)
            _buildScanResult(),
        ],
      ),
    );
  }

  Widget _buildScanResult() {
    final ok   = _success == true;
    final user = _lastUser;

    return Container(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ok ? const Color(0xFF0D3D1F) : const Color(0xFF3D0D0D),
            borderRadius: AppRadius.xl,
            border: Border.all(
              color: ok ? AppColors.success : AppColors.error, width: 2),
            boxShadow: [
              BoxShadow(
                color: (ok ? AppColors.success : AppColors.error).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône résultat
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (ok ? AppColors.success : AppColors.error).withOpacity(0.15),
                  ),
                  child: Icon(
                    ok ? Icons.check_circle : Icons.cancel,
                    color: ok ? AppColors.success : AppColors.error,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  ok ? '✅ Identité confirmée' : '❌ QR invalide ou non validé',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),

                if (ok && user != null) ...[
                  const SizedBox(height: 20),

                  // Photo de l'invité (vérification visuelle)
                  if (user.avatarUrl != null)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.success, width: 3),
                        boxShadow: [
                          BoxShadow(color: AppColors.success.withOpacity(0.3),
                              blurRadius: 16),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(user.avatarUrl!),
                      ),
                    ),

                  const SizedBox(height: 14),

                  Text(user.fullName,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 20, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center),

                  if (user.specialty != null)
                    Text(user.specialty!,
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),

                  if (user.institution != null)
                    Text(user.institution!,
                        style: const TextStyle(color: Colors.white54, fontSize: 13)),

                  if (user.country != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('🌍 ${user.country}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ),

                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: AppRadius.full,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.where_to_vote, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Arrivée enregistrée',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Text('Scan suivant dans 4s...',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFrame extends StatefulWidget {
  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260, height: 260,
      child: Stack(
        children: [
          // Coins du cadre
          ..._buildCorners(),
          // Ligne de scan animée
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Positioned(
              top: _anim.value * 250,
              left: 10, right: 10,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    AppColors.success,
                    Colors.transparent,
                  ]),
                  boxShadow: [
                    BoxShadow(color: AppColors.success.withOpacity(0.6),
                        blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 24.0;
    const thick = 3.0;
    const color = AppColors.success;

    return [
      // Top-left
      Positioned(top: 0, left: 0, child: _Corner(size, thick, color, top: true, left: true)),
      // Top-right
      Positioned(top: 0, right: 0, child: _Corner(size, thick, color, top: true, left: false)),
      // Bottom-left
      Positioned(bottom: 0, left: 0, child: _Corner(size, thick, color, top: false, left: true)),
      // Bottom-right
      Positioned(bottom: 0, right: 0, child: _Corner(size, thick, color, top: false, left: false)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double size;
  final double thick;
  final Color color;
  final bool top;
  final bool left;
  const _Corner(this.size, this.thick, this.color, {required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size,
      child: CustomPaint(painter: _CornerPainter(color, thick, top, left)));
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thick;
  final bool top;
  final bool left;
  const _CornerPainter(this.color, this.thick, this.top, this.left);

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..strokeWidth = thick
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    if (top && left) {
      c.drawLine(Offset(0, s.height), const Offset(0, 0), p);
      c.drawLine(const Offset(0, 0), Offset(s.width, 0), p);
    } else if (top && !left) {
      c.drawLine(Offset(0, 0), Offset(s.width, 0), p);
      c.drawLine(Offset(s.width, 0), Offset(s.width, s.height), p);
    } else if (!top && left) {
      c.drawLine(Offset(0, 0), Offset(0, s.height), p);
      c.drawLine(Offset(0, s.height), Offset(s.width, s.height), p);
    } else {
      c.drawLine(Offset(s.width, 0), Offset(s.width, s.height), p);
      c.drawLine(Offset(0, s.height), Offset(s.width, s.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════
// screens/moderator/moderator_shell.dart
// ═══════════════════════════════════════════════════════════════════
class ModeratorShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ModeratorShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) => Scaffold(body: shell);
}

// ═══════════════════════════════════════════════════════════════════
// screens/moderator/qa_console_screen.dart
// ═══════════════════════════════════════════════════════════════════
class QaConsoleScreen extends StatefulWidget {
  const QaConsoleScreen({super.key});
  @override
  State<QaConsoleScreen> createState() => _QaConsoleScreenState();
}

class _QaConsoleScreenState extends State<QaConsoleScreen> {
  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModeratorProvider>();
    final session = mod.session;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(session?.title ?? 'Console Q&A'),
        actions: [
          if (session != null) ...[
            // Toggle Q&A
            Switch(
              value: session.qaOpen,
              onChanged: (v) => mod.toggleQa(v),
              activeColor: AppColors.success,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: session == null
          ? _buildNoSession()
          : Column(
              children: [
                // Status bar
                _buildStatusBar(mod, session),
                // Questions list
                Expanded(
                  child: mod.loading
                      ? const Center(child: CircularProgressIndicator())
                      : mod.questions.isEmpty
                          ? _buildNoQuestions(session)
                          : _buildQuestionsList(mod),
                ),
              ],
            ),
    );
  }

  Widget _buildNoSession() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none, size: 64, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Aucune session assignée',
              style: AppTextStyles.bodyMedium),
          Text('Contactez l\'administrateur pour l\'assignation',
              style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ModeratorProvider mod, CongressSession session) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: session.qaOpen ? AppColors.success : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            session.qaOpen ? 'Q&A OUVERT' : 'Q&A FERMÉ',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: session.qaOpen ? AppColors.success : AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text('${mod.totalQuestions} questions · ${mod.pendingCount} en attente',
              style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }

  Widget _buildNoQuestions(CongressSession session) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            session.qaOpen
                ? 'En attente des questions des participants...'
                : 'Ouvrez le Q&A pour recevoir des questions',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(ModeratorProvider mod) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mod.sortedQuestions.length,
      itemBuilder: (_, i) {
        final q = mod.sortedQuestions[i];
        return _ModeratorQuestionCard(
          question: q,
          rank: i,
          onPin:    () => mod.pinQuestion(q.id),
          onAnswer: () => mod.markAnswered(q.id),
          onReject: () => mod.rejectQuestion(q.id),
        );
      },
    );
  }
}

class _ModeratorQuestionCard extends StatelessWidget {
  final CongressQuestion question;
  final int rank;
  final VoidCallback onPin;
  final VoidCallback onAnswer;
  final VoidCallback onReject;

  const _ModeratorQuestionCard({
    required this.question,
    required this.rank,
    required this.onPin,
    required this.onAnswer,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final isPinned  = q.isPinned;
    final isAnswered= q.isAnswered;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lg,
          border: Border(
            left: BorderSide(
              color: isPinned ? AppColors.success
                  : isAnswered ? AppColors.info
                  : rank == 0 ? AppColors.navyMid : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges + rang
              Row(children: [
                if (isPinned)
                  _Badge('📌 Épinglée', AppColors.success),
                if (isAnswered)
                  _Badge('✅ Posée', AppColors.info),
                if (rank == 0 && !isPinned)
                  _Badge('#1 Top', AppColors.navyMid),
                const Spacer(),
                Row(children: [
                  const Icon(Icons.thumb_up, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${q.votesCount}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ]),
              const SizedBox(height: 8),

              // Question text
              Text(q.text,
                  style: const TextStyle(fontSize: 14, height: 1.5,
                      color: AppColors.textPrimary)),

              const SizedBox(height: 8),
              // Auteur
              Row(children: [
                if (q.authorCountry != null)
                  Text(q.authorCountry!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(q.displayAuthor,
                    style: AppTextStyles.bodyMedium),
              ]),

              // Actions (seulement si pas encore traitée)
              if (!isAnswered) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(children: [
                  if (!isPinned)
                    _ActionBtn('Épingler', Icons.push_pin_outlined,
                        AppColors.success, onPin),
                  if (!isPinned) const SizedBox(width: 8),
                  _ActionBtn('Posée', Icons.check, AppColors.info, onAnswer),
                  const SizedBox(width: 8),
                  _ActionBtn('Rejeter', Icons.close, AppColors.error, onReject),
                ]),
              ],
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
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: AppRadius.sm,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color,
              fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/guest/guest_shell.dart
// ═══════════════════════════════════════════════════════════════════
class GuestShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const GuestShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'Mon Badge',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Programme',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Q&A',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Réseau',
          ),
        ],
      ),
    );
  }
}
