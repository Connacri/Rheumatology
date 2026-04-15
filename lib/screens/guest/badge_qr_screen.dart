// ═══════════════════════════════════════════════════════════════════
// screens/guest/badge_qr_screen.dart
// ═══════════════════════════════════════════════════════════════════
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';


class BadgeQrScreen extends StatefulWidget {
  const BadgeQrScreen({super.key});
  @override
  State<BadgeQrScreen> createState() => _BadgeQrScreenState();
}

class _BadgeQrScreenState extends State<BadgeQrScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  final _badgeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Écoute les changements de profil en realtime
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeRealtime();
    });
  }

  void _subscribeRealtime() {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    // Le NotificationProvider gère le realtime dans main_provider.dart
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Mon Invitation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => context.read<AuthProvider>().refreshUser(),
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AuthProvider>().refreshUser(),
        color: AppColors.navyMid,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // En-tête congrès
              _buildCongressHeader(),
              const SizedBox(height: 20),

              // Contenu selon statut
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: switch (user.status) {
                  'validated' => _buildValidatedBadge(user),
                  'pending'   => _buildPendingState(),
                  'reserved'  => _buildReservedState(user),
                  'banned'    => _buildBannedState(),
                  _           => _buildPendingState(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── En-tête congrès ───────────────────────────────────────────────
  Widget _buildCongressHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryHeader,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const Icon(Icons.medical_services, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('14ème Congrès Orano-Eurélieen',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 13)),
                Text('de Rhumatologie & 2ème Congrès International',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.calendar_today, color: Colors.white54, size: 11),
                  SizedBox(width: 4),
                  Text('23 - 25 Avril 2026',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  SizedBox(width: 12),
                  Icon(Icons.location_on, color: Colors.white54, size: 11),
                  SizedBox(width: 4),
                  Text('Oran, Algérie',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge validé ─────────────────────────────────────────────────
  Widget _buildValidatedBadge(CongressUser user) {
    return RepaintBoundary(
      key: _badgeKey,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: AppRadius.xl,
          gradient: AppGradients.validatedBadge,
          boxShadow: AppShadows.badge,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Pattern de fond holographique
            _HolographicPattern(),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // ── Titre badge ──
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text('INVITATION OFFICIELLE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          )),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Photo ──
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3),
                            blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white24,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null
                          ? Text(user.initials,
                              style: const TextStyle(fontSize: 36,
                                  color: Colors.white, fontWeight: FontWeight.w800))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Nom ──
                  Text(user.fullName.toUpperCase(),
                      style: AppTextStyles.badgeName,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  if (user.specialty != null)
                    Text(user.specialty!,
                        style: const TextStyle(color: Colors.white70,
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  if (user.institution != null)
                    Text(user.institution!,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  if (user.country != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(user.country!,
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ),

                  const SizedBox(height: 20),

                  // ── Ligne de séparation ──
                  Container(height: 1,
                      color: Colors.white.withOpacity(0.2), margin:
                      const EdgeInsets.symmetric(horizontal: 16)),
                  const SizedBox(height: 20),

                  // ── QR Code ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.lg,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2),
                            blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: QrImageView(
                      data: user.qrToken!,
                      version: QrVersions.auto,
                      size: 180,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.navyDeep,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.navyDeep,
                      ),
                      embeddedImage: const AssetImage('assets/images/logo_small.png'),
                      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(32, 32)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── N° badge ──
                  Text(
                    'N° ${user.qrToken!.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),

                  // ── Statut arrivée ──
                  if (user.hasArrived) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: AppRadius.full,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.where_to_vote, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Arrivée enregistrée',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Footer badge ──
                  const Text('Présentez ce QR à la réception',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── État en attente ───────────────────────────────────────────────
  Widget _buildPendingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.xl,
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: AppColors.navyMid.withOpacity(0.3),
            highlightColor: AppColors.navyLight.withOpacity(0.6),
            child: const Icon(Icons.hourglass_top, size: 72, color: AppColors.navyMid),
          ),
          const SizedBox(height: 20),
          const Text('Dossier en cours d\'examen',
              style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'L\'administration du congrès examine votre dossier d\'inscription. '
            'Vous recevrez une notification push dès que votre invitation sera confirmée.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Progress des étapes
          _StatusStep(done: true,  label: 'Compte créé'),
          _StatusStep(done: true,  label: 'Profil complété'),
          _StatusStep(done: false, label: 'Validation en cours...', active: true),
          _StatusStep(done: false, label: 'Réception du QR badge'),
        ],
      ),
    );
  }

  // ── État réservé ─────────────────────────────────────────────────
  Widget _buildReservedState(CongressUser user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 64, color: AppColors.warning),
          const SizedBox(height: 16),
          const Text('Informations complémentaires requises',
              style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
          if (user.adminNotes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.message_outlined, color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(user.adminNotes!,
                        style: TextStyle(color: AppColors.warning.withAlpha(220),
                            fontSize: 13, height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Compléter mon dossier'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
          ),
        ],
      ),
    );
  }

  // ── État banni ───────────────────────────────────────────────────
  Widget _buildBannedState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel_outlined, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Inscription non retenue',
              style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'Votre demande d\'inscription n\'a pas été retenue pour cette édition. '
            'Contactez l\'organisation pour plus d\'informations.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.email_outlined),
            label: const Text('Contacter l\'organisation'),
          ),
        ],
      ),
    );
  }
}

// ── Pattern holographique ─────────────────────────────────────────
class _HolographicPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _HoloPainter()),
    );
  }
}

class _HoloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Cercles concentriques
    for (double r = 20; r < 400; r += 30) {
      canvas.drawCircle(Offset(size.width * 0.8, 0), r, paint);
    }
    // Lignes diagonales
    paint.color = Colors.white.withOpacity(0.03);
    for (double i = -200; i < size.width + 200; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i + 100, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Status Step ───────────────────────────────────────────────────
class _StatusStep extends StatelessWidget {
  final bool done;
  final bool active;
  final String label;
  const _StatusStep({required this.done, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.success : active
                ? AppColors.navyMid.withOpacity(0.1) : AppColors.border,
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : active
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.navyMid))
                  : null,
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(
          fontSize: 13,
          color: done || active ? AppColors.textPrimary : AppColors.textMuted,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// widgets/status_badge.dart
// ═══════════════════════════════════════════════════════════════════
class StatusBadge extends StatelessWidget {
  final String status;
  final bool large;
  const StatusBadge({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'validated' => ('Validé',     AppColors.success, Icons.check_circle),
      'pending'   => ('En attente', AppColors.warning, Icons.hourglass_top),
      'reserved'  => ('Réserve',    AppColors.info,    Icons.info_outline),
      'banned'    => ('Refusé',     AppColors.error,   Icons.cancel),
      _           => ('Inconnu',    AppColors.textMuted, Icons.help_outline),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical:   large ? 6  : 3,
      ),
      decoration: BoxDecoration(
        color:  color.withOpacity(0.12),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 16 : 12, color: color),
          SizedBox(width: large ? 6 : 4),
          Text(label, style: TextStyle(
            fontSize: large ? 13 : 11,
            color: color,
            fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// widgets/loading_button.dart
// ═══════════════════════════════════════════════════════════════════
class LoadingButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onPressed;
  final ButtonStyle? style;

  const LoadingButton({
    super.key,
    required this.loading,
    required this.label,
    this.onPressed,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ))
            : Text(label),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// widgets/congress_header.dart
// ═══════════════════════════════════════════════════════════════════
class CongressHeader extends StatelessWidget {
  final bool compact;
  const CongressHeader({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primaryHeader,
            ),
            child: const Icon(Icons.medical_services, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          const Text('14ème Congrès Orano-Eurélieen',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.navyMid), textAlign: TextAlign.center),
          const Text('de Rhumatologie & 2ème Congrès International',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          const Text('Oran, Algérie • 23-25 Avril 2026',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: const BoxDecoration(gradient: AppGradients.primaryHeader),
      child: const Column(
        children: [
          Icon(Icons.medical_services, color: Colors.white, size: 48),
          SizedBox(height: 12),
          Text('14ème Congrès Orano-Eurélieen\nde Rhumatologie',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          SizedBox(height: 4),
          Text('2ème Congrès International • AAMRO',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          SizedBox(height: 8),
          Text('23 - 25 Avril 2026 • Oran, Algérie',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
