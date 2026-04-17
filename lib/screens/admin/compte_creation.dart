import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';



class compteCreation extends StatefulWidget {
  const compteCreation({super.key});

  @override
  State<compteCreation> createState() => _compteCreationState();
}

class _compteCreationState extends State<compteCreation> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // --- LOGIQUE METIER ---

  String _generatePassword({int length = 12}) {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%&*';
    final random = Random.secure();
    return List.generate(length, (index) => charset[random.nextInt(charset.length)]).join();
  }

  Future<void> _handleRegistration() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar("Veuillez entrer un email valide", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final password = _generatePassword();

      // Création Firebase
      await _auth.createUserWithEmailAndPassword(email: email, password: password);

      // Succès : On affiche le mot de passe à l'utilisateur
      _showSuccessDialog(email, password);

    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Une erreur est survenue", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI COMPONENTS ---

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showSuccessDialog(String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Compte créé !"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Voici votre mot de passe généré automatiquement :"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(password, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      _showSnackBar("Copié dans le presse-papier", Colors.green);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text("Note: Pensez à le changer dès votre première connexion.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription Rapide")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 80, color: Colors.blue),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegistration,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Générer mon accès"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}