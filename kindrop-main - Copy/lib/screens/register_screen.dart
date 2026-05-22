import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart' show makeGoogleSignIn;

import '../theme.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_field.dart';
import '../widgets/widgets.dart';

class RegisterScreen extends StatefulWidget {
  final Future<void> Function() onChanged;
  const RegisterScreen({super.key, required this.onChanged});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _role = 'donor';
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _orgName = TextEditingController();
  String _error = '';
  bool _loading = false;

  Future<void> _register() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'role': _role,
        'orgName': _role == 'organization' ? _orgName.text.trim() : null,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final googleUser = await makeGoogleSignIn().signIn();
      if (googleUser == null) return;
      final auth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final ref = FirebaseFirestore.instance.collection('users').doc(result.user!.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'uid': result.user!.uid,
          'fullName': result.user!.displayName ?? 'Google User',
          'email': result.user!.email,
          'role': _role,
          'orgName': _role == 'organization' ? 'My Organization' : null,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Logo
                  Container(
                    width: 64, height: 64,
                    decoration: brutalBox(kPrimary, borderWidth: 4),
                    alignment: Alignment.center,
                    child: const Text('🤝', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(height: 10),
                  Text('JOIN KINDROP',
                      style: GoogleFonts.anton(fontSize: 28, color: kDark)),
                  const SizedBox(height: 28),

                  // Role selector
                  Row(children: [
                    Expanded(child: _RoleChip(
                      text: 'Donor',
                      active: _role == 'donor',
                      onTap: () => setState(() => _role = 'donor'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _RoleChip(
                      text: 'Organization',
                      active: _role == 'organization',
                      onTap: () => setState(() => _role = 'organization'),
                    )),
                  ]),
                  const SizedBox(height: 24),

                  if (_error.isNotEmpty) ErrorBox(error: _error),

                  BrutalField(controller: _fullName, hint: 'Full Name'),
                  const SizedBox(height: 12),

                  if (_role == 'organization') ...[
                    BrutalField(controller: _orgName, hint: 'Organization Name'),
                    const SizedBox(height: 12),
                  ],

                  BrutalField(controller: _email, hint: 'Email'),
                  const SizedBox(height: 12),
                  BrutalField(controller: _phone, hint: 'Phone Number'),
                  const SizedBox(height: 12),
                  BrutalField(controller: _password, hint: 'Password', obscure: true),
                  const SizedBox(height: 20),

                  BrutalButton.primary(
                    text: _loading ? 'Joining...' : 'Join Kindrop 🤝',
                    onTap: _loading ? null : _register,
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Row(children: [
                    const Expanded(child: Divider(color: Color(0x44888888))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR JOIN WITH',
                          style: GoogleFonts.spaceMono(
                              fontSize: 10, fontWeight: FontWeight.bold, color: kMuted)),
                    ),
                    const Expanded(child: Divider(color: Color(0x44888888))),
                  ]),
                  const SizedBox(height: 20),

                  BrutalButton.outline(
                    text: 'Google Sign In',
                    onTap: _loading ? null : _googleSignIn,
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Already have account? Sign In',
                      style: TextStyle(color: kMuted, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _RoleChip({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: brutalBox(active ? kPrimary : kCard),
        child: Center(
          child: Text(text,
              style: TextStyle(
                  color: active ? kDark : kMuted, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}