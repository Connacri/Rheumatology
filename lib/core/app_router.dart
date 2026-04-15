import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_screens.dart';
import '../screens/auth/auth_screens.dart';
import '../screens/splash_screen.dart';

import '../screens/auth/profile_completion_screen.dart';



import '../screens/receptionist/qr_scanner_screen.dart';

import '../screens/guest/badge_qr_screen.dart';
import '../screens/guest/program_timeline_screen.dart';
import '../screens/guest/qa_screen.dart';

import '../screens/display/grand_ecran_screen.dart';

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  static final _shellAdmin = GlobalKey<NavigatorState>(debugLabel: 'admin');
  static final _shellAdminUsers = GlobalKey<NavigatorState>(debugLabel: 'admin_users');
  static final _shellGuest = GlobalKey<NavigatorState>(debugLabel: 'guest');
  static final _shellGuestProg = GlobalKey<NavigatorState>(debugLabel: 'guest_prog');
  static final _shellGuestQA = GlobalKey<NavigatorState>(debugLabel: 'guest_qa');
  static final _shellGuestNet = GlobalKey<NavigatorState>(debugLabel: 'guest_net');
  static final _shellMod   = GlobalKey<NavigatorState>(debugLabel: 'mod');

  static GoRouter router(AuthProvider auth) => GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc    = state.matchedLocation;
      final status = auth.status;
      final user   = auth.user;

      // Toujours afficher le splash pendant le chargement
      if (status == AuthStatus.loading) {
        return loc == '/splash' ? null : '/splash';
      }

      // Non authentifié → pages auth uniquement (on retire /splash d'ici)
      final authPaths = ['/login', '/register', '/forgot-password'];
      if (status == AuthStatus.unauthenticated) {
        return authPaths.contains(loc) ? null : '/login';
      }

      // Email non vérifié
      if (status == AuthStatus.needsEmailVerification) {
        return loc == '/verify-email' ? null : '/verify-email';
      }

      // Profil incomplet
      if (status == AuthStatus.needsProfileCompletion) {
        return loc == '/complete-profile' ? null : '/complete-profile';
      }

      // Déjà sur une page auth ou splash → rediriger selon rôle
      if (authPaths.contains(loc) || loc == '/splash' || loc == '/verify-email' || loc == '/complete-profile') {
        return _homeForRole(user?.role ?? 'guest');
      }

      // Vérifier que le user accède seulement à ses routes
      if (user != null) {
        if (loc.startsWith('/admin') && !user.isAdmin) {
          return _homeForRole(user.role);
        }
        if (loc.startsWith('/moderator') && !user.isModerator && !user.isAdmin) {
          return _homeForRole(user.role);
        }
        if (loc.startsWith('/receptionist') && user.role != 'receptionist' && !user.isAdmin) {
          return _homeForRole(user.role);
        }
      }

      return null;
    },
    routes: [
      // ── Public ──────────────────────────────────────────────────
      GoRoute(path: '/splash',          builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register',        builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email',    builder: (_, __) => const EmailVerificationScreen()),
      GoRoute(path: '/complete-profile',builder: (_, __) => const ProfileCompletionScreen()),

      // ── Grand écran (display mode) ───────────────────────────────
      GoRoute(path: '/display/:sessionId',
        builder: (_, state) => GrandEcranScreen(
          sessionId: int.parse(state.pathParameters['sessionId'] ?? '0'),
        ),
      ),

      // ── Admin Shell ──────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AdminShell(shell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellAdmin,
            routes: [
              GoRoute(
                path: '/admin',
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellAdminUsers,
            routes: [
              GoRoute(
                path: '/admin/users',
                builder: (_, __) => const UserListScreen(),
                routes: [
                  GoRoute(
                    path: ':userId',
                    parentNavigatorKey: _rootKey,
                    builder: (_, state) => UserDetailScreen(
                      userId: state.pathParameters['userId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Moderator Shell ──────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ModeratorShell(shell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellMod,
            routes: [
              GoRoute(
                path: '/moderator',
                builder: (_, __) => const QaConsoleScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Receptionist ─────────────────────────────────────────────
      GoRoute(
        path: '/receptionist',
        builder: (_, __) => const QrScannerScreen(),
      ),

      // ── Guest Shell ──────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => GuestShell(shell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellGuest,
            routes: [
              GoRoute(path: '/guest', builder: (_, __) => const BadgeQrScreen()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellGuestProg,
            routes: [
              GoRoute(path: '/guest/program', builder: (_, __) => const ProgramTimelineScreen()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellGuestQA,
            routes: [
              GoRoute(path: '/guest/qa', builder: (_, __) => const QaScreen()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellGuestNet,
            routes: [
              GoRoute(path: '/guest/network', builder: (_, __) => const NetworkingScreen()),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.uri}')),
    ),
  );

  static String _homeForRole(String role) {
    return switch (role) {
      'super_admin' || 'admin' => '/admin',
      'moderator'              => '/moderator',
      'receptionist'           => '/receptionist',
      _                        => '/guest',
    };
  }
}
