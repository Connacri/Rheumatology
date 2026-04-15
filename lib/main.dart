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
const supabaseUrl    = 'https://tkmzeywijodhoudjgtxr.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrbXpleXdpam9kaG91ZGpndHhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NzgwNTEsImV4cCI6MjA5MTM1NDA1MX0.s4Ip4JHH3coBUVRmmde5gH6L9_Z4y7POXKN0l9R63AE';

Future<void> main({bool isTest = false}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait + Landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Status bar transparent
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Firebase (push notifications)


  if (!isTest) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
    httpClient: SupabaseAuthInterceptor(),
  );

  runApp(const CongressOranApp());
}

class CongressOranApp extends StatefulWidget {
  final bool isTest;

  const CongressOranApp({super.key, this.isTest = false});

  @override
  State<CongressOranApp> createState() => _CongressOranAppState();
}

class _CongressOranAppState extends State<CongressOranApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: widget.isTest
          ? [
        Provider(create: (_) => DummyAuth()),
      ]
          : [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ModeratorProvider()),
        ChangeNotifierProvider(create: (_) => GuestProvider()),
      ],
      child: Builder(
        builder: (context) {
          _router ??= AppRouter.router(context.read<AuthProvider>());
          
          return MaterialApp.router(
            title: '14ème Congrès Rhumatologie Oran',
            debugShowCheckedModeBanner: false,
            theme:       AppTheme.light,
            darkTheme:   AppTheme.displayDark,
            themeMode:   ThemeMode.light,
            routerConfig: _router!,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

class DummyAuth extends ChangeNotifier {}