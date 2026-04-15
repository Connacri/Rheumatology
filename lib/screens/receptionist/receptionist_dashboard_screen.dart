import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';

class ReceptionistDashboardScreen extends StatefulWidget {
  const ReceptionistDashboardScreen({super.key});

  @override
  State<ReceptionistDashboardScreen> createState() => _ReceptionistDashboardScreenState();
}

class _ReceptionistDashboardScreenState extends State<ReceptionistDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Accueil Réception'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => admin.loadUsers(),
        child: CustomScrollView(
          slivers: [
            // ── Statistiques ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _StatCard(
                      label: 'Validés',
                      value: admin.validatedCount.toString(),
                      color: AppColors.success,
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Présents',
                      value: admin.arrivedCount.toString(),
                      color: AppColors.info,
                      icon: Icons.people_outline,
                    ),
                  ],
                ),
              ),
            ),

            // ── Barre de recherche ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un invité...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.lg,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => admin.setSearch(v),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Liste des users ──
            if (admin.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (admin.filteredUsers.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Aucun invité trouvé')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = admin.filteredUsers[index];
                      return _UserCard(user: user);
                    },
                    childCount: admin.filteredUsers.length,
                  ),
                ),
              ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/receptionist/scan'),
        backgroundColor: AppColors.navyMid,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scanner Badge', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lg,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.headlineMedium.copyWith(color: color)),
                Text(label, style: AppTextStyles.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final CongressUser user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final ok = user.isValidated || user.hasArrived;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: AppColors.navyLight,
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null ? Text(user.fullName.isNotEmpty ? user.fullName[0] : '?') : null,
        ),
        title: Text(user.fullName, style: AppTextStyles.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user.specialty ?? "Sans spécialité"} • ${user.country ?? "N/A"}',
                style: AppTextStyles.labelSmall),
            const SizedBox(height: 4),
            _StatusBadge(user: user),
          ],
        ),
        trailing: user.hasArrived 
          ? const Icon(Icons.check_circle, color: AppColors.success)
          : (user.isValidated 
              ? IconButton(
                  icon: const Icon(Icons.login, color: AppColors.info),
                  onPressed: () => _confirmArrival(context),
                  tooltip: 'Valider l\'arrivée',
                )
              : const Icon(Icons.hourglass_empty, color: Colors.orange)),
      ),
    );
  }

  void _confirmArrival(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer l\'arrivée'),
        content: Text('Voulez-vous marquer ${user.fullName} comme présent ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AdminProvider>().markArrivalByQrToken(user.qrToken ?? '');
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final CongressUser user;
  const _StatusBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    String text = user.status;

    if (user.hasArrived) {
      color = AppColors.success;
      text = 'PRÉSENT';
    } else if (user.isValidated) {
      color = AppColors.info;
      text = 'VALIDÉ';
    } else if (user.isPending) {
      color = Colors.orange;
      text = 'EN ATTENTE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
