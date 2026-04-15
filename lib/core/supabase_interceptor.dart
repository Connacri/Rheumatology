import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;

class SupabaseAuthInterceptor extends http.BaseClient {
  final http.Client _inner = http.Client();
  
  // L'anon key est nécessaire pour toutes les requêtes Supabase REST
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrbXpleXdpam9kaG91ZGpndHhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NzgwNTEsImV4cCI6MjA5MTM1NDA1MX0.s4Ip4JHH3coBUVRmmde5gH6L9_Z4y7POXKN0l9R63AE';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // S'assurer que les headers de base Supabase sont présents
    request.headers['apikey'] = _anonKey;
    if (!request.headers.containsKey('Authorization')) {
      request.headers['Authorization'] = 'Bearer $_anonKey';
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      request.headers['x-user-id'] = uid;
      dev.log('Supabase Request: ${request.method} ${request.url} (UID: $uid)');
    } else {
      dev.log('Supabase Request: ${request.method} ${request.url} (ANON)');
    }

    return _inner.send(request);
  }
}
