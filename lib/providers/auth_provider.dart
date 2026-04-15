import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/models.dart';

enum AuthStatus {
  loading,
  unauthenticated,
  needsEmailVerification,
  needsProfileCompletion,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  //final _auth = FirebaseAuth.instance;
  late final FirebaseAuth _auth;
  final _sb = sb.Supabase.instance.client;
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  CongressUser? _user;
  AuthStatus _status = AuthStatus.loading;
  String? _error;
  bool _uploadingAvatar = false;
  bool _isLoadingUser = false;

  CongressUser? get user   => _user;
  AuthStatus get status    => _status;
  String? get error        => _error;
  bool get uploadingAvatar => _uploadingAvatar;
  bool get isLoading       => _status == AuthStatus.loading || _isLoadingUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider({FirebaseAuth? auth}) {
    _auth = auth ?? FirebaseAuth.instance;
    _init();
  }

  // ── Init ──────────────────────────────────────────────────────────
  Future<void> _init() async {
    // 1. Charger l'état initial immédiatement
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      // Éviter de bloquer l'initialisation si possible, 
      // mais on a besoin du profil pour le routage initial
      await _loadAndRouteUser(firebaseUser);
    } else {
      _setStatus(AuthStatus.unauthenticated);
    }

    // 2. Écouter les changements d'auth
    // On retire le delay qui était une tentative de fix pour Windows
    // et on gère proprement les appels multiples
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) async {
    debugPrint('Auth state changed: ${firebaseUser?.uid}');
    if (firebaseUser != null) {
      // Si on est déjà en train de charger cet utilisateur, on ignore
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
      // 1. Vérifier si l'email est vérifié
      final isGoogle = firebaseUser.providerData.any((p) => p.providerId == 'google.com');
      
      // On ne reload que si nécessaire pour éviter les boucles infinies sur certaines plateformes
      // car reload() peut déclencher authStateChanges()
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

      // 2. Charger le profil depuis Supabase
      // On évite de refaire la requête si on a déjà les données et que c'est le même user
      if (_user?.id == updatedUser.uid && _status == AuthStatus.authenticated) {
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
      // On ne repasse en unauthenticated que si c'est vraiment une erreur critique
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
      
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setStatus(AuthStatus.unauthenticated);
        return 'Connexion annulée';
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        _setStatus(AuthStatus.unauthenticated);
        return 'Erreur d\'authentification Firebase';
      }

      // Vérifier/Créer le profil Supabase
      final existing = await _sb
          .from('congress_users')
          .select('id')
          .eq('id', firebaseUser.uid)
          .maybeSingle();

      if (existing == null) {
        await _sb.from('congress_users').insert({
          'id':             firebaseUser.uid,
          'email':          firebaseUser.email,
          'first_name':     firebaseUser.displayName?.split(' ').first ?? '',
          'last_name':      firebaseUser.displayName?.split(' ').skip(1).join(' ') ?? '',
          'avatar_url':     firebaseUser.photoURL,
          'google_id':      firebaseUser.uid,
          'role':           'guest',
          'status':         'pending',
          'email_verified': true,
          'profile_complete': false,
        });
      }

      return null;
    } catch (e) {
      _setStatus(AuthStatus.unauthenticated);
      return e.toString();
    }
  }

  // ── Email Sign Up ─────────────────────────────────────────────────
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('SIGNUP: Début de l\'inscription pour $email');
      _error = null;
      _setStatus(AuthStatus.loading);
      
      debugPrint('SIGNUP: Tentative createUserWithEmailAndPassword...');
      final res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        debugPrint('SIGNUP ERROR: Firebase user est null');
        return 'Erreur lors de l\'inscription';
      }
      debugPrint('SIGNUP: Utilisateur créé avec UID: ${res.user!.uid}');

      // Envoyer l'email de vérification
      debugPrint('SIGNUP: Envoi de l\'email de vérification...');
      await res.user!.sendEmailVerification();
      debugPrint('SIGNUP: Email de vérification envoyé');

      // Créer le profil minimal dans Supabase
      debugPrint('SIGNUP: Insertion dans Supabase (congress_users)...');
      await _sb.from('congress_users').insert({
        'id':               res.user!.uid,
        'email':            email,
        'first_name':       '',
        'last_name':        '',
        'role':             'guest',
        'status':           'pending',
        'email_verified':   false,
        'profile_complete': false,
      });
      debugPrint('SIGNUP: Profil Supabase créé avec succès');

      _setStatus(AuthStatus.needsEmailVerification);
      debugPrint('SIGNUP: Terminé avec succès');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('SIGNUP FIREBASE_ERROR: [${e.code}] ${e.message}');
      _setStatus(AuthStatus.unauthenticated);
      return _mapFirebaseError(e.code);
    } catch (e) {
      debugPrint('SIGNUP GENERAL_ERROR: $e');
      _setStatus(AuthStatus.unauthenticated);
      return e.toString();
    }
  }

  // ── Email Sign In ─────────────────────────────────────────────────
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _error = null;
      _setStatus(AuthStatus.loading);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      _setStatus(AuthStatus.unauthenticated);
      return _mapFirebaseError(e.code);
    } catch (e) {
      _setStatus(AuthStatus.unauthenticated);
      return e.toString();
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
      debugPrint('PROFILE: Début de completeProfile');
      _uploadingAvatar = true;
      notifyListeners();

      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('PROFILE ERROR: Aucun UID trouvé (session expirée)');
        return 'Session expirée';
      }

      String? avatarUrl;

      // Upload photo si fournie (Storage Supabase reste utilisable avec RLS adaptée)
      if (avatarFile != null) {
        debugPrint('PROFILE: Upload de l\'avatar (${avatarFile.path})...');
        final ext  = avatarFile.path.split('.').last;
        final path = 'avatars/$uid.$ext';
        await _sb.storage.from('congress-avatars').upload(
          path,
          avatarFile,
          fileOptions: const sb.FileOptions(upsert: true),
        );
        avatarUrl = _sb.storage.from('congress-avatars').getPublicUrl(path);
        debugPrint('PROFILE: Avatar uploadé: $avatarUrl');
      }

      final updateData = <String, dynamic>{
        'first_name':          firstName,
        'last_name':           lastName,
        'specialty':           specialty,
        'institution':         institution,
        'country':             country,
        'phone':               phone,
        'phone_country_code':  phoneCountryCode,
        'profile_complete':    true,
        'email_verified':      true,
      };
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      debugPrint('PROFILE: Mise à jour Supabase (congress_users)...');
      await _sb.from('congress_users')
          .upsert({
            'id':    uid,
            'email': _auth.currentUser?.email,
            ...updateData,
          });
      debugPrint('PROFILE: Profil mis à jour avec succès');

      debugPrint('PROFILE: Rechargement des données utilisateur...');
      await _loadAndRouteUser(_auth.currentUser!);
      debugPrint('PROFILE: Terminé');
      
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

  // ── Pick and crop avatar ──────────────────────────────────────────
  Future<File?> pickAvatar(ImageSource source) async {
    // Utiliser FilePicker sur Windows ou pour la galerie pour éviter les plantages
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

    // ImagePicker reste utilisé pour la caméra sur Mobile
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
      // google_sign_in n'est pas supporté sur Windows, on vérifie avant d'appeler
      if (!Platform.isWindows && !Platform.isLinux) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // Ignorer si le plugin n'est pas initialisé ou non supporté
    }
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
