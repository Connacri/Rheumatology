import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/models.dart';

enum AuthStatus {
  loading,
  unauthenticated,
  needsEmailVerification,
  needsProfileCompletion,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  late final FirebaseAuth _auth;
  
  // Dans la version 7.0+, GoogleSignIn utilise un singleton
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Supabase client — nullable pour les stubs de test.
  sb.SupabaseClient? _sbClient;
  sb.SupabaseClient get _sb => _sbClient ?? sb.Supabase.instance.client;

  CongressUser? _user;
  AuthStatus _status = AuthStatus.loading;
  String? _error;
  bool _uploadingAvatar = false;
  bool _isLoadingUser = false;

  // Flag interne : si true, _init() ne sera pas appelé (mode stub/test).
  final bool _isStub;

  CongressUser? get user   => _user;
  AuthStatus get status    => _status;
  String? get error        => _error;
  bool get uploadingAvatar => _uploadingAvatar;
  bool get isLoading       => _status == AuthStatus.loading || _isLoadingUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Constructeur principal (production) ───────────────────────────
  AuthProvider({FirebaseAuth? auth})
      : _isStub = false {
    _auth = auth ?? FirebaseAuth.instance;
    _init();
  }

  // ── Constructeur stub (tests uniquement) ─────────────────────────
  // N'appelle pas FirebaseAuth.instance ni _init().
  AuthProvider.stub()
      : _isStub = true {
    // FirebaseAuth non initialisé en test → on utilise un fake.
    // Le status reste 'unauthenticated' par défaut.
    _auth = FirebaseAuth.instance; // ignoré en stub — aucune méthode appelée
    _status = AuthStatus.unauthenticated;
  }

  // ── Init ──────────────────────────────────────────────────────────
  Future<void> _init() async {
    if (_isStub) return;

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await _loadAndRouteUser(firebaseUser);
    } else {
      _setStatus(AuthStatus.unauthenticated);
    }
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) async {
    if (_isStub) return;
    debugPrint('Auth state changed: ${firebaseUser?.uid}');
    if (firebaseUser != null) {
      if (_isLoadingUser && _user?.id == firebaseUser.uid) return;
      await _loadAndRouteUser(firebaseUser);
    } else {
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadAndRouteUser(User firebaseUser) async {
    if (_isLoadingUser) return;
    _isLoadingUser = true;

    try {
      _error = null;
      final isGoogle = firebaseUser.providerData
          .any((p) => p.providerId == 'google.com');

      if (!firebaseUser.emailVerified && !isGoogle) {
        await firebaseUser.reload();
      }

      final updatedUser = _auth.currentUser;
      if (updatedUser == null) {
        _setStatus(AuthStatus.unauthenticated);
        return;
      }

      if (!updatedUser.emailVerified && !isGoogle) {
        _setStatus(AuthStatus.needsEmailVerification);
        return;
      }

      if (_user?.id == updatedUser.uid &&
          _status == AuthStatus.authenticated) {
        return;
      }

      final data = await _sb
          .from('congress_users')
          .select()
          .eq('id', updatedUser.uid)
          .maybeSingle();

      if (data == null) {
        _setStatus(AuthStatus.needsProfileCompletion);
        return;
      }

      _user = CongressUser.fromJson(data);

      if (!_user!.profileComplete) {
        _setStatus(AuthStatus.needsProfileCompletion);
      } else {
        _setStatus(AuthStatus.authenticated);
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      _error = e.toString();
      if (_status == AuthStatus.loading) {
        _setStatus(AuthStatus.unauthenticated);
      }
    } finally {
      _isLoadingUser = false;
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────
  Future<String?> signInWithGoogle() async {
    try {
      _error = null;
      _setStatus(AuthStatus.loading);
      debugPrint('Démarrage de Google Sign-In (v7.2.0)...');

      // 1. Initialisation
      await _googleSignIn.initialize(
        serverClientId: '456602364782-q5tvhujm6hg6flh38h0aplkse03cvk3d.apps.googleusercontent.com',
      );

      // 2. Authentification (Identité)
      final googleUser = await _googleSignIn.authenticate();

      if (googleUser == null) {
        debugPrint('Google Sign-In annulé par l\'utilisateur.');
        _setStatus(AuthStatus.unauthenticated);
        return 'Connexion annulée';
      }

      debugPrint('Utilisateur Google obtenu: ${googleUser.email}');

      // 3. Obtenir les détails d'authentification (idToken)
      final googleAuth = await googleUser.authentication;
      
      // 4. Obtenir l'autorisation pour les scopes via authorizationClient (v7.2+)
      final scopes = ['email', 'profile', 'openid'];
      final authorization = await googleUser.authorizationClient.authorizeScopes(scopes);
      final accessToken = authorization.accessToken;

      // 5. Créer le credential Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Tentative de connexion à Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw 'Erreur lors de la récupération de l\'utilisateur Firebase.';
      }

      debugPrint('Connexion Firebase réussie: ${firebaseUser.uid}');

      // 5. Synchronisation avec Supabase
      final existing = await _sb
          .from('congress_users')
          .select('id')
          .eq('id', firebaseUser.uid)
          .maybeSingle();

      if (existing == null) {
        debugPrint('Nouvel utilisateur détecté, création du profil dans Supabase...');
        await _sb.from('congress_users').insert({
          'id': firebaseUser.uid,
          'email': firebaseUser.email,
          'first_name': firebaseUser.displayName?.split(' ').first ?? '',
          'last_name': firebaseUser.displayName?.split(' ').skip(1).join(' ') ?? '',
          'avatar_url': firebaseUser.photoURL,
          'google_id': firebaseUser.uid,
          'role': 'guest',
          'status': 'pending',
          'email_verified': true,
          'profile_complete': false,
        });
      }

      return null;
    } catch (e, stack) {
      debugPrint('ERREUR CRITIQUE Google Sign-In: $e');
      debugPrint('Stack trace: $stack');
      
      // En cas d'erreur, on déconnecte Google pour permettre une nouvelle tentative propre
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      
      _error = _handleGoogleError(e);
      _setStatus(AuthStatus.unauthenticated);
      return _error;
    }
  }

  String _handleGoogleError(dynamic e) {
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('network_error')) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    } else if (errorStr.contains('12500') || errorStr.contains('10')) {
      return 'Erreur de configuration Google (SHA-1/Package Name). Vérifiez que les clés SHA sont bien sur Firebase.';
    } else if (errorStr.contains('access_denied')) {
      return 'Accès refusé par Google.';
    }
    return 'Une erreur est survenue : $e';
  }

  // ── Email Sign Up ─────────────────────────────────────────────────
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _error = null;
      _setStatus(AuthStatus.loading);

      final res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (res.user == null) return 'Erreur lors de l\'inscription';

      await res.user!.sendEmailVerification();

      await _sb.from('congress_users').insert({
        'id': res.user!.uid,
        'email': email,
        'first_name': '',
        'last_name': '',
        'role': 'guest',
        'status': 'pending',
        'email_verified': false,
        'profile_complete': false,
      });

      _setStatus(AuthStatus.needsEmailVerification);
      
      // Envoi du mail de bienvenue (Optionnel)
      _sendWelcomeEmail(email, password);
      
      return null;
    } on FirebaseAuthException catch (e) {
      _setStatus(AuthStatus.unauthenticated);
      return _mapFirebaseError(e.code);
    } catch (e, stack) {
      debugPrint('Google Sign-In Error: $e');
      debugPrint('Stack trace: $stack');
      _setStatus(AuthStatus.unauthenticated);
      return e.toString();
    }
  }

  // ── Email Sign In ─────────────────────────────────────────────────
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
// ... (rest of the code until the end of the class)
  }

  // ── Private Helper for Welcome Email ──────────────────────────────
  void _sendWelcomeEmail(String userEmail, String userPassword) async {
    // NOTE: Il est déconseillé de mettre des identifiants SMTP en dur dans le code client.
    // Idéalement, utilisez une Cloud Function ou un service de backend.
    String username = 'votre-email@gmail.com'; 
    String appPassword = 'votre-mot-de-passe-application'; 

    final smtpServer = gmail(username, appPassword);

    final message = Message()
      ..from = Address(username, 'AAMRO Congress')
      ..recipients.add(userEmail)
      ..subject = 'Bienvenue au Congrès AAMRO'
      ..html = """
        <h3>Bienvenue !</h3>
        <p>Votre compte a été créé avec succès pour le Congrès AAMRO.</p>
        <p>Voici vos identifiants de connexion :</p>
        <ul>
          <li><strong>Email :</strong> $userEmail</li>
          <li><strong>Mot de passe :</strong> $userPassword</li>
        </ul>
        <p>Veuillez vérifier votre email via le lien envoyé par Firebase pour activer votre compte.</p>
      """;

    try {
      await send(message, smtpServer);
      debugPrint('Email de bienvenue envoyé avec succès.');
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi de l\'email : $e');
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Resend verification email ─────────────────────────────────────
  Future<String?> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Utilisateur introuvable';
      await user.sendEmailVerification();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Complete Profile ──────────────────────────────────────────────
  Future<String?> completeProfile({
    required String firstName,
    required String lastName,
    required String specialty,
    String? institution,
    required String country,
    String? phone,
    String? phoneCountryCode,
    File? avatarFile,
  }) async {
    try {
      _uploadingAvatar = true;
      notifyListeners();

      final uid = _auth.currentUser?.uid;
      if (uid == null) return 'Session expirée';

      String? avatarUrl;

      if (avatarFile != null) {
        final ext = avatarFile.path.split('.').last;
        final path = 'avatars/$uid.$ext';
        await _sb.storage.from('congress-avatars').upload(
          path,
          avatarFile,
          fileOptions: const sb.FileOptions(upsert: true),
        );
        avatarUrl =
            _sb.storage.from('congress-avatars').getPublicUrl(path);
      }

      final updateData = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'specialty': specialty,
        'institution': institution,
        'country': country,
        'phone': phone,
        'phone_country_code': phoneCountryCode,
        'profile_complete': true,
        'email_verified': true,
      };
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      await _sb.from('congress_users').upsert({
        'id': uid,
        'email': _auth.currentUser?.email,
        ...updateData,
      });

      await _loadAndRouteUser(_auth.currentUser!);
      return null;
    } catch (e) {
      debugPrint('PROFILE ERROR: $e');
      return e.toString();
    } finally {
      _uploadingAvatar = false;
      notifyListeners();
    }
  }

  // ── Refresh user ──────────────────────────────────────────────────
  Future<void> refreshUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _loadAndRouteUser(user);
  }

  // ── Pick avatar ───────────────────────────────────────────────────
  Future<File?> pickAvatar(ImageSource source) async {
    if (Platform.isWindows || source == ImageSource.gallery) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  // ── Sign Out ──────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      if (!Platform.isWindows && !Platform.isLinux) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }

  // ── Helpers ───────────────────────────────────────────────────────
  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'weak-password':
        return 'Le mot de passe est trop faible';
      case 'invalid-email':
        return 'Format d\'email invalide';
      default:
        return 'Une erreur est survenue lors de l\'authentification';
    }
  }
}