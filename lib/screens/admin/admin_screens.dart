// ═══════════════════════════════════════════════════════════════════
// screens/admin/user_list_screen.dart
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

import '../guest/badge_qr_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});
  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Consumer<AdminProvider>(
          builder: (_, a, __) => Text('Inscrits (${a.filteredUsers.length})'),
        ),
        actions: [
          Consumer<AdminProvider>(
            builder: (_, a, __) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: a.loadUsers,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de recherche ──
          _buildSearchBar(),
          // ── Filtres statut ──
          _buildFilterBar(),
          // ── Stats rapides ──
          _buildStatsRow(),
          // ── Liste ──
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (_, admin, __) {
                if (admin.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = admin.filteredUsers;
                if (users.isEmpty) {
                  return _buildEmpty();
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: users.length,
                  itemBuilder: (_, i) => _UserCard(
                    user: users[i],
                    onTap: () => context.push('/admin/users/${users[i].id}'),
                    onValidate: users[i].isPending || users[i].isReserved
                        ? () => _quickValidate(users[i].id)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (q) => context.read<AdminProvider>().setSearch(q),
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, spécialité, pays...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<AdminProvider>().setSearch('');
                  })
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all',       'Tous'),
      ('pending',   'En attente'),
      ('validated', 'Validés'),
      ('reserved',  'Réserves'),
      ('banned',    'Refusés'),
    ];
    return Container(
      color: Colors.white,
      height: 50,
      child: Consumer<AdminProvider>(
        builder: (_, admin, __) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: filters.map((f) {
            final sel = admin.statusFilter == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.$2),
                selected: sel,
                onSelected: (_) => admin.setFilter(f.$1),
                selectedColor: AppColors.navyMid,
                labelStyle: TextStyle(
                  color:      sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                ),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<AdminProvider>(
      builder: (_, admin, __) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            _StatChip(label: 'Total',   value: admin.totalGuests,   color: AppColors.navyMid),
            const SizedBox(width: 8),
            _StatChip(label: 'Attente', value: admin.pendingCount,  color: AppColors.warning),
            const SizedBox(width: 8),
            _StatChip(label: 'Validés', value: admin.validatedCount,color: AppColors.success),
            const SizedBox(width: 8),
            _StatChip(label: 'Arrivés', value: admin.arrivedCount,  color: AppColors.info),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('Aucun inscrit trouvé', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _quickValidate(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider cet inscrit ?'),
        content: const Text('L\'invité recevra son QR badge immédiatement.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AdminProvider>().validateUser(userId);
    }
  }
}

class _UserCard extends StatelessWidget {
  final CongressUser user;
  final VoidCallback onTap;
  final VoidCallback? onValidate;

  const _UserCard({required this.user, required this.onTap, this.onValidate});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.navyMid.withOpacity(0.1),
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(user.initials,
                        style: const TextStyle(color: AppColors.navyMid,
                            fontWeight: FontWeight.bold, fontSize: 16))
                    : null,
              ),
              const SizedBox(width: 12),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (user.specialty != null)
                      Text(user.specialty!, style: AppTextStyles.bodyMedium),
                    if (user.institution != null)
                      Text(user.institution!,
                          style: AppTextStyles.labelSmall,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusBadge(status: user.status),
                        if (user.hasArrived) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.where_to_vote, color: AppColors.success, size: 14),
                        ],
                        if (user.country != null) ...[
                          const SizedBox(width: 6),
                          Text('🌍 ${user.country}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions rapides
              Column(
                children: [
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  if (onValidate != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onValidate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: AppRadius.sm,
                          border: Border.all(color: AppColors.success.withOpacity(0.4)),
                        ),
                        child: const Text('Valider',
                            style: TextStyle(fontSize: 10, color: AppColors.success,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.sm,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/admin/user_detail_screen.dart
// ═══════════════════════════════════════════════════════════════════
class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});
  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  CongressUser? _user;
  bool _loading = true;
  bool _acting  = false;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final u = await context.read<AdminProvider>().getUserById(widget.userId);
    if (mounted) setState(() { _user = u; _loading = false; });
  }

  Future<void> _act(Future<void> Function() fn) async {
    setState(() => _acting = true);
    await fn();
    await _load();
    setState(() => _acting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Utilisateur introuvable')),
      );
    }
    final u = _user!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(u.fullName),
        actions: [
          if (_acting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Card profil ──
            _buildProfileCard(u),
            const SizedBox(height: 16),

            // ── Infos ──
            _buildInfoCard(u),
            const SizedBox(height: 16),

            // ── Notes admin ──
            if (u.adminNotes != null) _buildNotesCard(u),
            if (u.adminNotes != null) const SizedBox(height: 16),

            // ── Actions ──
            _buildActions(u),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(CongressUser u) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Photo avec badge QR mini si validé
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.navyMid.withOpacity(0.1),
                  backgroundImage: u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null,
                  child: u.avatarUrl == null
                      ? Text(u.initials,
                          style: const TextStyle(fontSize: 24, color: AppColors.navyMid,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                if (u.isValidated)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.fullName,
                      style: AppTextStyles.titleLarge),
                  if (u.specialty != null)
                    Text(u.specialty!, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 8),
                  StatusBadge(status: u.status, large: true),
                  const SizedBox(height: 4),
                  Text('Inscrit le ${_formatDate(u.createdAt)}',
                      style: AppTextStyles.labelSmall),
                  if (u.hasArrived)
                    Text('Arrivé le ${_formatDate(u.arrivedAt!)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(CongressUser u) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            const Divider(),
            _InfoRow(Icons.badge_outlined,       'Spécialité',   u.specialty   ?? '—'),
            _InfoRow(Icons.business_outlined,    'Établissement',u.institution ?? '—'),
            _InfoRow(Icons.flag_outlined,        'Pays',         u.country     ?? '—'),
            _InfoRow(Icons.phone_outlined,       'Téléphone',    u.displayPhone.isEmpty ? '—' : u.displayPhone),
            _InfoRow(Icons.email_outlined,       'Email',        u.email       ?? '—'),
            _InfoRow(Icons.qr_code,             'QR Token',     u.qrToken != null
                ? u.qrToken!.substring(0, 16) + '...' : '—'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(CongressUser u) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.comment_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note de l\'admin', style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 12)),
                const SizedBox(height: 4),
                Text(u.adminNotes!,
                    style: TextStyle(color: AppColors.warning.withAlpha(210), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(CongressUser u) {
    if (u.isValidated) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('Invitation envoyée et active',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ],
              ),
              if (u.hasArrived) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.where_to_vote, color: AppColors.info, size: 18),
                    SizedBox(width: 8),
                    Text('Arrivée confirmée à la réception',
                        style: TextStyle(color: AppColors.info, fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (u.isBanned) {
      return ElevatedButton.icon(
        onPressed: _acting ? null : () => _act(() =>
            context.read<AdminProvider>().resetToPending(u.id)),
        icon: const Icon(Icons.restore),
        label: const Text('Remettre en attente'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.textSecondary),
      );
    }

    return Column(
      children: [
        // Valider
        ElevatedButton.icon(
          onPressed: _acting ? null : () => _act(() =>
              context.read<AdminProvider>().validateUser(u.id)),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('✅ Valider et envoyer l\'invitation'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
        ),
        const SizedBox(height: 10),

        // Demander des infos
        OutlinedButton.icon(
          onPressed: _acting ? null : _showReserveDialog,
          icon: const Icon(Icons.warning_amber_outlined),
          label: const Text('⚠️ Demander des informations'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.warning,
            side: const BorderSide(color: AppColors.warning),
          ),
        ),
        const SizedBox(height: 10),

        // Refuser
        OutlinedButton.icon(
          onPressed: _acting ? null : () => _showBanConfirm(),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('🚫 Refuser l\'inscription'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  void _showReserveDialog() {
    _notesCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informations requises'),
        content: TextField(
          controller: _notesCtrl,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Précisez les informations manquantes à l\'invité...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (_notesCtrl.text.trim().isNotEmpty) {
                _act(() => context.read<AdminProvider>()
                    .reserveUser(_user!.id, _notesCtrl.text.trim()));
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  void _showBanConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser cette inscription ?'),
        content: const Text(
            'L\'invité recevra une notification de refus. Cette action est réversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _act(() => context.read<AdminProvider>().banUser(_user!.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} '
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          SizedBox(width: 100,
              child: Text(label, style: AppTextStyles.bodyMedium)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500,
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/admin/admin_shell.dart
// ═══════════════════════════════════════════════════════════════════
class AdminShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AdminShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i,
            initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Inscrits',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/admin/dashboard_screen.dart
// ═══════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: Consumer<AdminProvider>(
        builder: (_, admin, __) => RefreshIndicator(
          onRefresh: () => admin.loadUsers(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Congrès header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryHeader,
                  borderRadius: AppRadius.lg,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('14ème Congrès Rhumatologie Oran',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w800, fontSize: 13)),
                        Text('23-25 Avril 2026 · Administration',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('Statistiques inscriptions',
                  style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _KpiCard('Total inscrits', '${admin.totalGuests}',
                      Icons.people, AppColors.navyMid),
                  _KpiCard('Pré-inscrits Web', '${admin.webPendingCount}',
                      Icons.web_outlined, Colors.deepPurple),
                  _KpiCard('En attente', '${admin.pendingCount}',
                      Icons.hourglass_top, AppColors.warning),
                  _KpiCard('Validés', '${admin.validatedCount}',
                      Icons.check_circle, AppColors.success),
                  _KpiCard('Arrivés', '${admin.arrivedCount}',
                      Icons.where_to_vote, AppColors.info),
                  _KpiCard('Refusés', '${admin.bannedCount}',
                      Icons.cancel, AppColors.error),
                ],
              ),

              const SizedBox(height: 20),
              const Text('Pays représentés', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              ...admin.countByCountry.entries.take(8).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key,
                        style: AppTextStyles.bodyMedium)),
                    Text('${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            color: AppColors.navyMid)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: admin.totalGuests > 0
                            ? e.value / admin.totalGuests : 0,
                        backgroundColor: AppColors.border,
                        color: AppColors.navyMid,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),)
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: color)),
                Text(label, style: AppTextStyles.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
