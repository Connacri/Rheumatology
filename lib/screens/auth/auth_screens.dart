// ═══════════════════════════════════════════════════════════════════
// screens/auth/login_screen.dart
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

import '../guest/badge_qr_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _googleLoad = false;
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await context.read<AuthProvider>().signInWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) _showError(err);
  }

  Future<void> _loginGoogle() async {
    setState(() => _googleLoad = true);
    final err = await context.read<AuthProvider>().signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoad = false);
    if (err != null) _showError(err);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // En-tête congrès
              const CongressHeader(compact: true),
              const SizedBox(height: 32),

              // Titre
              const Text('Connexion', style: AppTextStyles.displayLarge),
              const SizedBox(height: 6),
              const Text('Accédez à votre invitation',
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // ── Bouton Google ──
              _GoogleButton(loading: _googleLoad, onTap: _loginGoogle),
              const SizedBox(height: 20),

              // ── Divider ──
              const _Divider(label: 'ou continuer avec email'),
              const SizedBox(height: 20),

              // ── Formulaire ──
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Adresse email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _loginEmail(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Minimum 6 caractères' : null,
                    ),
                  ],
                ),
              ),

              // ── Mot de passe oublié ──
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),

              const SizedBox(height: 8),

              // ── Bouton connexion ──
              LoadingButton(
                loading: _loading,
                label: 'Se connecter',
                onPressed: _loginEmail,
              ),

              const SizedBox(height: 24),

              // ── Lien inscription ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Pas encore de compte ?",
                      style: AppTextStyles.bodyMedium),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('S\'inscrire au congrès'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/auth/register_screen.dart
// ═══════════════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading    = false;
  bool _googleLoad = false;
  bool _obscure    = true;
  bool _obscureC   = true;
  bool _accepted   = false;

  Future<void> _registerEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      _showError('Veuillez accepter les conditions d\'utilisation');
      return;
    }
    setState(() => _loading = true);
    final err = await context.read<AuthProvider>().signUpWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) _showError(err);
  }

  Future<void> _googleRegister() async {
    setState(() => _googleLoad = true);
    final err = await context.read<AuthProvider>().signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoad = false);
    if (err != null) _showError(err);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Inscription au congrès'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Badge d'info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryHeader,
                  borderRadius: AppRadius.lg,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Après inscription, un administrateur validera votre dossier. '
                        'Vous recevrez votre QR badge par notification.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _GoogleButton(loading: _googleLoad, onTap: _googleRegister),
              const SizedBox(height: 20),
              const _Divider(label: 'ou créer un compte avec email'),
              const SizedBox(height: 20),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Adresse email *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        helperText: 'Minimum 8 caractères',
                      ),
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'Minimum 8 caractères' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureC,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _registerEmail(),
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureC ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscureC = !_obscureC),
                        ),
                      ),
                      validator: (v) {
                        if (v != _passCtrl.text) return 'Les mots de passe ne correspondent pas';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // CGU
              Row(
                children: [
                  Checkbox(
                    value: _accepted,
                    activeColor: AppColors.navyMid,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      "J'accepte les conditions d'utilisation et la politique de confidentialité",
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              LoadingButton(
                loading: _loading,
                label: 'Créer mon compte',
                onPressed: _registerEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/auth/forgot_password_screen.dart
// ═══════════════════════════════════════════════════════════════════
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent    = false;

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un email valide')));
      return;
    }
    setState(() => _loading = true);
    await context.read<AuthProvider>().sendPasswordReset(email);
    if (!mounted) return;
    setState(() { _loading = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Réinitialiser le mot de passe')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset, color: AppColors.info, size: 40),
            ),
            const SizedBox(height: 24),

            if (!_sent) ...[
              const Text('Mot de passe oublié ?',
                  style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Entrez votre adresse email et nous vous enverrons\nun lien pour réinitialiser votre mot de passe.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Adresse email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: _loading,
                label: 'Envoyer le lien de réinitialisation',
                onPressed: _send,
              ),
            ] else ...[
              const Text('Email envoyé !',
                  style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Un email de réinitialisation a été envoyé à\n${_emailCtrl.text}.\n\n'
                'Vérifiez votre boîte de réception et vos spams.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour à la connexion'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// screens/auth/email_verification_screen.dart
// ═══════════════════════════════════════════════════════════════════
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _resending = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    final err = await context.read<AuthProvider>().resendVerificationEmail();
    if (!mounted) return;
    setState(() => _resending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Email renvoyé avec succès'),
      backgroundColor: err != null ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryHeader,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 32),
              const Text('Vérifiez votre email',
                  style: AppTextStyles.displayLarge, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Nous avons envoyé un lien de confirmation à votre adresse email.\n\n'
                'Cliquez sur le lien dans l\'email pour activer votre compte.\n'
                'Pensez à vérifier vos courriers indésirables (spams) si vous ne le voyez pas.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => context.read<AuthProvider>().refreshUser(),
                icon: const Icon(Icons.refresh),
                label: const Text('J\'ai vérifié mon email'),
              ),
              const SizedBox(height: 12),
              LoadingButton(

                loading: _resending,
                label: 'Renvoyer l\'email',
                onPressed: _resend,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.navyMid),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          backgroundColor: Colors.white,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text('Continuer avec Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: AppTextStyles.labelSmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
