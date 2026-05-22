// brutal_button.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class BrutalButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;

  const BrutalButton._({required this.text, required this.onTap, required this.bg, required this.fg});

  factory BrutalButton.primary({required String text, required VoidCallback? onTap}) =>
      BrutalButton._(text: text, onTap: onTap, bg: kPrimary, fg: kDark);

  factory BrutalButton.dark({required String text, required VoidCallback? onTap}) =>
      BrutalButton._(text: text, onTap: onTap, bg: kDark, fg: Colors.white);

  factory BrutalButton.outline({required String text, required VoidCallback? onTap}) =>
      BrutalButton._(text: text, onTap: onTap, bg: Colors.white, fg: kDark);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: brutalBox(bg),
        child: Center(
          child: Text(text,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }
}