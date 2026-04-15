import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'core/app_router.dart';
import 'core/supabase_interceptor.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';

import 'firebase_options.dart';

// ── Supabase config ────────────────────────────────────────────────
const supabaseUrl = 'https://tkmzeywijodhoudjgtxr.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrbXpleXdpam9kaG91ZGpndHhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NzgwNTEsImV4cCI6MjA5MTM1NDA1MX0.s4Ip4JHH3coBUVRmmde5gH6L9_Z4y7POXKN0l9R63AE';

Future<void> main({bool isTest = false}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  if (!isTest) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
    httpClient: SupabaseAuthInterceptor(),
  );

  runApp(CongressOranApp(isTest: isTest));
}

// ═══════════════════════════════════════════════════════════════════
// CongressOranApp
// ═══════════════════════════════════════════════════════════════════
class CongressOranApp extends StatefulWidget {
  final bool isTest;
  const CongressOranApp({super.key, this.isTest = false});

  @override
  State<CongressOranApp> createState() => _CongressOranAppState();
}

class _CongressOranAppState extends State<CongressOranApp> {
  // Nullable intentionnel :
  //   - test → initialisé dans initState (pas de provider needed)
  //   - prod → initialisé dans le Builder (contexte provider requis)
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (widget.isTest) {
      _router = _buildTestRouter();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Mode TEST ────────────────────────────────────────────────────
    if (widget.isTest) {
      return ChangeNotifierProvider<AuthProvider>(
        // Stub qui n'appelle pas FirebaseAuth.instance
        create: (_) => AuthProvider.stub(),
        child: MaterialApp.router(
          title: 'Test',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: _router!,
        ),
      );
    }

    // ── Mode PRODUCTION ──────────────────────────────────────────────
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ModeratorProvider()),
        ChangeNotifierProvider(create: (_) => GuestProvider()),
      ],
      // Builder est indispensable : il fournit un BuildContext descendant
      // du MultiProvider, permettant context.read<AuthProvider>().
      child: Builder(
        builder: (ctx) {
          _router ??= AppRouter.router(ctx.read<AuthProvider>());
          return MaterialApp.router(
            title: '14ème Congrès Rhumatologie Oran',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.displayDark,
            themeMode: ThemeMode.light,
            routerConfig: _router!,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: child!,
            ),
          );
        },
      ),
    );
  }

  GoRouter _buildTestRouter() => GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Test OK')),
        ),
      ),
    ],
  );
}