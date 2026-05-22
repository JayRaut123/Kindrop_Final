// brutal_field.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class BrutalField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  const BrutalField({super.key, required this.controller, required this.hint, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: brutalInputDecoration(hint: hint),
    );
  }
}