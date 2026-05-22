import 'package:flutter/material.dart';

// ── Colors (matches index.css) ────────────────────────────────────────────────
const kPrimary = Color(0xFFCBF43E);
const kDark    = Color(0xFF0D0D0D);
const kCard    = Color(0xFFF2F2F2);
const kMuted   = Color(0xFF888888);

// ── Brutalist box decoration ──────────────────────────────────────────────────
BoxDecoration brutalBox(Color color, {double borderWidth = 2}) {
  return BoxDecoration(
    color: color,
    border: Border.all(color: kDark, width: borderWidth),
    boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
  );
}

// ── Input decoration ──────────────────────────────────────────────────────────
InputDecoration brutalInputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kDark, width: 2),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kDark, width: 2),
    ),
  );
}