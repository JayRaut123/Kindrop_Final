import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../kindrop_route.dart';
import '../main.dart' show makeGoogleSignIn;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../theme.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_field.dart';
import '../widgets/widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function() onChanged;
  const LoginScreen({super.key, required this.onChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = ''; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      await widget.onChanged();
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
          'role': 'donor',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _enterDemo(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kindrop_demo_user', jsonEncode({
      'uid': 'demo_$role',
      'fullName': role == 'donor'
          ? 'Demo Donor'
          : role == 'delivery'
              ? 'Demo Delivery Partner'
              : 'Demo Organization',
      'email': 'demo@kindrop.com',
      'role': role,
      'orgName': role == 'organization' ? 'Kindrop Demo Home' : null,
      'createdAt': DateTime.now().toIso8601String(),
    }));
    await widget.onChanged();
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
                  const SizedBox(height: 40),

                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: brutalBox(kPrimary, borderWidth: 4),
                    alignment: Alignment.center,
                    child: const Text('🤝', style: TextStyle(fontSize: 36)),
                  ),
                  const SizedBox(height: 16),
                  Text('KINDROP',
                      style: GoogleFonts.anton(fontSize: 40, letterSpacing: -1, color: kDark)),
                  const SizedBox(height: 40),

                  if (_error.isNotEmpty) ErrorBox(error: _error),

                  BrutalField(controller: _email, hint: 'Email'),
                  const SizedBox(height: 12),
                  BrutalField(controller: _password, hint: 'Password', obscure: true),
                  const SizedBox(height: 16),

                  BrutalButton.dark(
                    text: _loading ? 'Signing In...' : 'Sign In',
                    onTap: _loading ? null : _signIn,
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Row(children: [
                    const Expanded(child: Divider(color: Color(0x44888888))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR CONTINUE WITH',
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

                  BrutalButton.primary(
                    text: 'Create Account',
                    onTap: () => Navigator.push(context,
                        KindropRoute(
                            builder: (_) => RegisterScreen(onChanged: widget.onChanged))),
                  ),
                  const SizedBox(height: 32),

                  Text('QUICK ACCESS (DEMO MODE)',
                      style: GoogleFonts.spaceMono(
                          fontSize: 10, fontWeight: FontWeight.bold, color: kMuted)),
                  const SizedBox(height: 10),

                  Row(children: [
                    Expanded(child: _SmallDemoButton(
                        text: 'Enter as Donor', onTap: () => _enterDemo('donor'))),
                    const SizedBox(width: 8),
                    Expanded(child: _SmallDemoButton(
                        text: 'Enter as Delivery Partner', onTap: () => _enterDemo('delivery'))),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallDemoButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SmallDemoButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: brutalBox(kCard, borderWidth: 1),
        child: Center(
          child: Text(text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}