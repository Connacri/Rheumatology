import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../guest/badge_qr_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});
  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _specialtyCtrl  = TextEditingController();
  final _institutionCtrl= TextEditingController();

  File?   _avatarFile;
  bool    _loading = false;
  int     _step    = 0; // 0=photo, 1=identité, 2=professionnel, 3=contact

  PhoneNumber? _phoneNumber;
  String? _selectedCountry;
  String? _specialtySelected;

  // Listes
  static const _specialties = [
    'Rhumatologie', 'Médecine interne', 'Orthopédie', 'Médecine générale',
    'Cardiologie', 'Dermatologie', 'Endocrinologie', 'Immunologie',
    'Neurologie', 'Radiologie', 'Chirurgie', 'Pharmacologie',
    'Recherche médicale', 'Étudiant en médecine', 'Autre',
  ];

  static const _countries = [
    'Algérie', 'France', 'Maroc', 'Tunisie', 'Égypte', 'Jordanie',
    'Arabie Saoudite', 'Koweït', 'Turquie', 'Azerbaïdjan', 'Sénégal',
    'Libye', 'Belgique', 'Suisse', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    // Pré-remplir depuis le profil Google si dispo
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _firstNameCtrl.text = user.firstName;
      _lastNameCtrl.text  = user.lastName;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _specialtyCtrl.dispose();
    _institutionCtrl.dispose();
    super.dispose();
  }

  // ── Avatar picker ─────────────────────────────────────────────────
  Future<void> _pickAvatar(ImageSource source) async {
    final auth   = context.read<AuthProvider>();
    final picked = await auth.pickAvatar(source);
    if (picked == null) return;

    // Le plugin image_cropper ne supporte pas Windows.
    // On ignore le crop sur desktop.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setState(() => _avatarFile = picked);
      return;
    }

    /// Crop circulaire (Mobile uniquement)
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recadrer la photo',
          toolbarColor: AppColors.navyMid,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Recadrer',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped != null) {
      setState(() => _avatarFile = File(cropped.path));
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Choisir une photo', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.infoBg,
                child: Icon(Icons.camera_alt, color: AppColors.info)),
              title: const Text('Prendre une photo'),
              onTap: () { Navigator.pop(context); _pickAvatar(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.infoBg,
                child: Icon(Icons.photo_library, color: AppColors.info)),
              title: const Text('Choisir depuis la galerie'),
              onTap: () { Navigator.pop(context); _pickAvatar(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    debugPrint('SUBMIT_FORM: Début de la soumission du formulaire');
    if (!_formKey.currentState!.validate()) {
      debugPrint('SUBMIT_FORM ERROR: Validation du formulaire échouée');
      return;
    }
    if (_avatarFile == null) {
      debugPrint('SUBMIT_FORM ERROR: Pas d\'avatar');
      _showSnack('Une photo de profil est requise pour votre badge', isError: true);
      setState(() => _step = 0);
      return;
    }
    if (_specialtySelected == null) {
      debugPrint('SUBMIT_FORM ERROR: Pas de spécialité sélectionnée');
      _showSnack('Veuillez sélectionner votre spécialité', isError: true);
      return;
    }

    setState(() => _loading = true);
    debugPrint('SUBMIT_FORM: Appel de authProvider.completeProfile...');
    
    final err = await context.read<AuthProvider>().completeProfile(
      firstName:        _firstNameCtrl.text.trim(),
      lastName:         _lastNameCtrl.text.trim(),
      specialty:        _specialtySelected!,
      institution:      _institutionCtrl.text.trim().isEmpty ? null : _institutionCtrl.text.trim(),
      country:          _selectedCountry ?? 'Algérie',
      phone:            _phoneNumber?.number,
      phoneCountryCode: _phoneNumber?.countryCode,
      avatarFile:       _avatarFile,
    );

    if (!mounted) {
      debugPrint('SUBMIT_FORM: Le widget n\'est plus monté après l\'appel');
      return;
    }
    
    setState(() => _loading = false);
    
    if (err != null) {
      debugPrint('SUBMIT_FORM ERROR: Retour de completeProfile: $err');
      _showSnack(err, isError: true);
    } else {
      debugPrint('SUBMIT_FORM SUCCESS: Profil complété avec succès');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header avec progress ──
            _buildHeader(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: [
                      _buildStepPhoto(),
                      _buildStepIdentity(),
                      _buildStepProfessional(),
                      _buildStepContact(),
                    ][_step],
                  ),
                ),
              ),
            ),

            // ── Navigation boutons ──
            _buildNavigation(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final steps = ['Photo', 'Identité', 'Profession', 'Contact'];
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Compléter votre profil', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text('Étape ${_step + 1} sur ${steps.length} — ${steps[_step]}',
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: List.generate(steps.length, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _step ? AppColors.navyMid : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  // ── STEP 0 : Photo ───────────────────────────────────────────────
  Widget _buildStepPhoto() {
    return Column(
      key: const ValueKey('photo'),
      children: [
        const SizedBox(height: 24),
        const Text('📷 Photo de profil', style: AppTextStyles.headlineMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Votre photo sera intégrée à votre badge digital QR.\n'
          'Elle sera vérifiée visuellement à la réception pour sécuriser l\'accès.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Avatar
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Photo ou placeholder
              Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _avatarFile == null ? AppGradients.primaryHeader : null,
                  boxShadow: AppShadows.badge,
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatarFile != null
                    ? Image.file(_avatarFile!, fit: BoxFit.cover)
                    : const Icon(Icons.person, color: Colors.white60, size: 80),
              ),

              // Bouton appareil photo
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (_avatarFile == null)
          OutlinedButton.icon(
            onPressed: _showPhotoOptions,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Ajouter une photo'),
          )
        else
          TextButton.icon(
            onPressed: _showPhotoOptions,
            icon: const Icon(Icons.edit),
            label: const Text('Changer la photo'),
          ),

        const SizedBox(height: 32),

        // Exigences
        _RequirementItem(
          icon: Icons.check_circle,
          color: AppColors.success,
          text: 'Visage visible et cadré',
        ),
        _RequirementItem(
          icon: Icons.check_circle,
          color: AppColors.success,
          text: 'Photo récente et ressemblante',
        ),
        _RequirementItem(
          icon: Icons.cancel,
          color: AppColors.error,
          text: 'Pas de lunettes de soleil ni chapeau',
        ),
      ],
    );
  }

  // ── STEP 1 : Identité ────────────────────────────────────────────
  Widget _buildStepIdentity() {
    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('👤 Votre identité', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        const Text('Ces informations apparaîtront sur votre badge.',
            style: AppTextStyles.bodyMedium),
        const SizedBox(height: 28),
        TextFormField(
          controller: _firstNameCtrl,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Prénom *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _lastNameCtrl,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nom *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
        ),

        const SizedBox(height: 24),

        // Pays de résidence
        const Text('Pays *', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCountry,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.flag_outlined),
            hintText: 'Sélectionnez votre pays',
          ),
          items: _countries.map((c) => DropdownMenuItem(
            value: c,
            child: Text(c),
          )).toList(),
          onChanged: (v) => setState(() => _selectedCountry = v),
          validator: (v) => v == null ? 'Pays requis' : null,
        ),
      ],
    );
  }

  // ── STEP 2 : Professionnel ───────────────────────────────────────
  Widget _buildStepProfessional() {
    return Column(
      key: const ValueKey('professional'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('🩺 Profil professionnel', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        const Text('Partagez votre spécialité médicale.',
            style: AppTextStyles.bodyMedium),
        const SizedBox(height: 28),

        // Spécialité — dropdown
        const Text('Spécialité *', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _specialtySelected,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.medical_services_outlined),
            hintText: 'Choisissez votre spécialité',
          ),
          items: _specialties.map((s) => DropdownMenuItem(
            value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _specialtySelected = v),
          validator: (v) => v == null ? 'Spécialité requise' : null,
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _institutionCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Établissement / Hôpital (optionnel)',
            prefixIcon: Icon(Icons.business_outlined),
            hintText: 'Ex: CHU Oran, Clinique des Orangers...',
          ),
        ),
      ],
    );
  }

  // ── STEP 3 : Contact ─────────────────────────────────────────────
  Widget _buildStepContact() {
    return Column(
      key: const ValueKey('contact'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('📱 Numéro de téléphone', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        const Text(
          'Optionnel. Il sera visible uniquement par vos connexions acceptées dans le réseau du congrès.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 28),

        // ── Champ téléphone avec drapeau ──────────────────────────
        IntlPhoneField(
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: '07 00 00 00 00',
            border: OutlineInputBorder(),
          ),
          initialCountryCode: 'DZ', // Algérie par défaut
          flagsButtonPadding: const EdgeInsets.only(left: 8),
          showDropdownIcon: true,
          dropdownIconPosition: IconPosition.trailing,
          dropdownIcon: const Icon(Icons.arrow_drop_down, color: AppColors.navyMid),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
          onChanged: (phone) {
            _phoneNumber = phone;
          },
          onCountryChanged: (country) {
            // Pays sélectionné via le picker téléphone
          },
        ),

        const SizedBox(height: 32),

        // Récapitulatif
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.summarize_outlined, color: AppColors.info, size: 18),
                SizedBox(width: 8),
                Text('Récapitulatif', style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.info)),
              ]),
              const SizedBox(height: 12),
              _SummaryRow('Photo',        _avatarFile != null ? '✅ Ajoutée' : '❌ Manquante'),
              _SummaryRow('Prénom',       _firstNameCtrl.text.isEmpty ? '—' : _firstNameCtrl.text),
              _SummaryRow('Nom',          _lastNameCtrl.text.isEmpty  ? '—' : _lastNameCtrl.text),
              _SummaryRow('Spécialité',   _specialtySelected ?? '—'),
              _SummaryRow('Établissement',_institutionCtrl.text.isEmpty ? 'Non renseigné' : _institutionCtrl.text),
              _SummaryRow('Pays',         _selectedCountry ?? '—'),
            ],
          ),
        ),
      ],
    );
  }

  // ── Navigation ───────────────────────────────────────────────────
  Widget _buildNavigation() {
    final isLast = _step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Retour'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: isLast
                ? LoadingButton(
                    loading: _loading,
                    label: 'Soumettre mon inscription 🚀',
                    onPressed: _submit,
                  )
                : ElevatedButton(
                    onPressed: () {
                      if (_step == 0 && _avatarFile == null) {
                        _showSnack('Veuillez ajouter une photo de profil', isError: true);
                        return;
                      }
                      if (_step == 1 && !_formKey.currentState!.validate()) return;
                      setState(() => _step++);
                    },
                    child: const Text('Continuer'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────
class _RequirementItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _RequirementItem({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary))),
      ]),
    );
  }
}
