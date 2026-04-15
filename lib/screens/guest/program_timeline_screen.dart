import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';

import '../../services/services.dart';

class ProgramTimelineScreen extends StatefulWidget {
  const ProgramTimelineScreen({super.key});
  @override
  State<ProgramTimelineScreen> createState() => _ProgramTimelineScreenState();
}

class _ProgramTimelineScreenState extends State<ProgramTimelineScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Timer _timer;
  DateTime _now = DateTime.now();
  final _scrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];

  final _days = [
    DateTime(2026, 4, 23),
    DateTime(2026, 4, 24),
    DateTime(2026, 4, 25),
  ];
  final _dayLabels = ['Jeu. 23', 'Ven. 24', 'Sam. 25'];

  @override
  void initState() {
    super.initState();
    // Sélectionner l'onglet du jour courant
    final todayIdx = _days.indexWhere(
      (d) => d.year == _now.year && d.month == _now.month && d.day == _now.day,
    );
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: todayIdx >= 0 ? todayIdx : 0,
    );

    // Mise à jour chaque minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Auto-scroll vers la session en cours après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSession();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabCtrl.dispose();
    for (final c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _scrollToCurrentSession() {
    final dayIdx = _tabCtrl.index;
    final sessions = ProgramService.sessionsForDay(_days[dayIdx]);
    final currentIdx = _findCurrentSessionIndex(sessions);
    if (currentIdx <= 0) return;

    final offset = (currentIdx * 88.0) - 100;
    final ctrl = _scrollControllers[dayIdx];
    if (ctrl.hasClients) {
      ctrl.animateTo(
        offset.clamp(0, ctrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  int _findCurrentSessionIndex(List<CongressSession> sessions) {
    for (int i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final next = i < sessions.length - 1 ? sessions[i + 1] : null;
      final start = _toDateTime(s);
      final end = next != null ? _toDateTime(next) : start.add(const Duration(minutes: 30));
      if (_now.isAfter(start) && _now.isBefore(end)) return i;
    }
    return -1;
  }

  CongressSession? _getCurrentSession(List<CongressSession> sessions) {
    final idx = _findCurrentSessionIndex(sessions);
    return idx >= 0 ? sessions[idx] : null;
  }

  DateTime _toDateTime(CongressSession s) {
    final parts = s.startTime.replaceAll('h', ':').split(':');
    return DateTime(
      s.date.year, s.date.month, s.date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '00') ?? 0,
    );
  }

  bool _isPast(CongressSession s) => _toDateTime(s).isBefore(_now);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Programme'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          onTap: (_) {
            Future.delayed(const Duration(milliseconds: 200), _scrollToCurrentSession);
          },
          tabs: _dayLabels.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: List.generate(3, (i) => _buildDayView(i)),
      ),
    );
  }

  Widget _buildDayView(int dayIdx) {
    final day      = _days[dayIdx];
    final sessions = ProgramService.sessionsForDay(day);
    final current  = _getCurrentSession(sessions);

    return Column(
      children: [
        // ── Bandeau session en cours ──
        if (current != null && day.day == _now.day)
          _CurrentSessionBanner(session: current),

        // ── Timeline ──
        Expanded(
          child: ListView.builder(
            controller: _scrollControllers[dayIdx],
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            itemBuilder: (_, i) {
              final s        = sessions[i];
              final isCurrent= current?.startTime == s.startTime &&
                               day.day == _now.day;
              final isPast   = _isPast(s) && !isCurrent;
              final isFirst  = i == 0;
              final isLast   = i == sessions.length - 1;

              return TimelineTile(
                alignment: TimelineAlign.manual,
                lineXY: 0.20,
                isFirst: isFirst,
                isLast:  isLast,
                indicatorStyle: IndicatorStyle(
                  width:  isCurrent ? 20 : 14,
                  height: isCurrent ? 20 : 14,
                  color:  _indicatorColor(s, isCurrent, isPast),
                  iconStyle: isCurrent
                      ? IconStyle(
                          iconData: Icons.play_arrow,
                          color: Colors.white,
                          fontSize: 12,
                        )
                      : null,
                  padding: const EdgeInsets.all(4),
                ),
                beforeLineStyle: LineStyle(
                  color: isPast
                      ? AppColors.navyMid.withOpacity(0.35)
                      : AppColors.border,
                  thickness: 2,
                ),
                startChild: _TimeLabel(
                  time: s.startTime,
                  isCurrent: isCurrent,
                  isPast: isPast,
                ),
                endChild: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
                  child: _SessionCard(
                    session: s,
                    isCurrent: isCurrent,
                    isPast: isPast,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _indicatorColor(CongressSession s, bool isCurrent, bool isPast) {
    if (isCurrent)      return AppColors.success;
    if (s.type == 'break' || s.type == 'ceremony') return AppColors.ceremony;
    if (s.type == 'symposium') return AppColors.symposium;
    if (s.type == 'workshop')  return AppColors.workshop;
    if (isPast)         return AppColors.border;
    return AppColors.navyMid;
  }
}

// ── Bandeau session en cours ─────────────────────────────────────────────────
class _CurrentSessionBanner extends StatefulWidget {
  final CongressSession session;
  const _CurrentSessionBanner({required this.session});
  @override
  State<_CurrentSessionBanner> createState() => _CurrentSessionBannerState();
}

class _CurrentSessionBannerState extends State<_CurrentSessionBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D4A1F), Color(0xFF1A6B3A)],
        ),
        borderRadius: AppRadius.lg,
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.greenAccent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(_pulse.value * 0.8),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('EN COURS MAINTENANT',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Text(s.startTime,
                      style: const TextStyle(color: Colors.white70, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),

              // Titre
              Text(
                s.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Orateur
              if (s.speakerName != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person_outline, color: Colors.white54, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${s.speakerName}${s.speakerCountry != null ? ' — ${s.speakerCountry}' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ]),
              ],

              // Badges type
              const SizedBox(height: 8),
              Row(children: [
                _TypeBadge(type: s.type),
                if (s.isZoom) ...[
                  const SizedBox(width: 6),
                  _ZoomBadge(),
                ],
                if (s.hall != null) ...[
                  const SizedBox(width: 6),
                  _HallBadge(hall: s.hall!),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time label ───────────────────────────────────────────────────────────────
class _TimeLabel extends StatelessWidget {
  final String time;
  final bool isCurrent;
  final bool isPast;

  const _TimeLabel({
    required this.time,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        time,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
          color: isCurrent
              ? AppColors.success
              : isPast
                  ? AppColors.textMuted
                  : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Session card ─────────────────────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final CongressSession session;
  final bool isCurrent;
  final bool isPast;

  const _SessionCard({
    required this.session,
    required this.isCurrent,
    required this.isPast,
  });

  Color get _cardBg {
    if (isCurrent) return const Color(0xFFE8F5E9);
    if (session.isBreak || session.isCeremony) return const Color(0xFFFFF8E1);
    if (session.isSymposium) return const Color(0xFFF3E5F5);
    if (session.isWorkshop) return const Color(0xFFE0F7FA);
    if (isPast) return const Color(0xFFF8F9FA);
    return Colors.white;
  }

  Color get _borderColor {
    if (isCurrent) return AppColors.success;
    if (session.isSymposium) return AppColors.symposium.withOpacity(0.4);
    if (session.isWorkshop)  return AppColors.workshop.withOpacity(0.4);
    if (session.isCeremony)  return AppColors.ceremony.withOpacity(0.4);
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final s = session;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: AppRadius.md,
        border: Border.all(color: _borderColor, width: isCurrent ? 1.5 : 1),
        boxShadow: isCurrent
            ? [BoxShadow(color: AppColors.success.withOpacity(0.15),
                blurRadius: 8, offset: const Offset(0, 3))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badges en haut ──
          if (s.isSymposium || s.isWorkshop || s.isCeremony ||
              s.isBreak || s.isZoom || s.hall != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (!s.isTalk) _TypeBadge(type: s.type),
                  if (s.isZoom) _ZoomBadge(),
                  if (s.hall != null) _HallBadge(hall: s.hall!),
                ],
              ),
            ),

          // ── Titre ──
          Text(
            s.title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
              color: isPast ? AppColors.textMuted : AppColors.textPrimary,
              height: 1.4,
            ),
          ),

          // ── Orateur ──
          if (s.speakerName != null) ...[
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.person_outline,
                  size: 12,
                  color: isPast ? AppColors.textMuted : AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${s.speakerName}'
                  '${s.speakerCountry != null ? ' — ${s.speakerCountry}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isPast ? AppColors.textMuted : AppColors.textSecondary,
                    fontFamily: 'Poppins',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],

          // ── Indicateur "En cours" ──
          if (isCurrent) ...[
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 5),
              const Text('En cours',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  )),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Type badge ────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'symposium' => ('SYMPOSIUM',  AppColors.symposium),
      'workshop'  => ('WORKSHOP',   AppColors.workshop),
      'ceremony'  => ('CÉRÉMONIE',  AppColors.ceremony),
      'break'     => ('PAUSE',      AppColors.textMuted),
      _           => ('',           Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppRadius.sm,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, color: color,
              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: AppRadius.sm,
        border: Border.all(color: Colors.blue.withOpacity(0.4)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.videocam, size: 10, color: Colors.blue),
        SizedBox(width: 3),
        Text('ZOOM', style: TextStyle(fontSize: 9, color: Colors.blue,
            fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _HallBadge extends StatelessWidget {
  final String hall;
  const _HallBadge({required this.hall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.workshop.withOpacity(0.1),
        borderRadius: AppRadius.sm,
        border: Border.all(color: AppColors.workshop.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.room, size: 10, color: AppColors.workshop),
        const SizedBox(width: 3),
        Text(hall, style: const TextStyle(fontSize: 9, color: AppColors.workshop,
            fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
