import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/donation.dart';

// ── Field Label ───────────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceMono(
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }
}

// ── Error Box ─────────────────────────────────────────────────────────────────
class ErrorBox extends StatelessWidget {
  final String error;
  const ErrorBox({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFEBEE),
        border: Border(left: BorderSide(color: Colors.red, width: 4)),
      ),
      child: Text(error, style: const TextStyle(color: Colors.red)),
    );
  }
}

// ── Empty Box ─────────────────────────────────────────────────────────────────
class EmptyBox extends StatelessWidget {
  final String text;
  const EmptyBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26, width: 2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 11, color: kMuted, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  const StatCard(
      {super.key, required this.label, required this.value, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: kDark, width: 2),
        boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.spaceMono(
                fontSize: 9, fontWeight: FontWeight.bold, color: kMuted)),
        const Spacer(),
        Text(value, style: GoogleFonts.bungee(fontSize: 28, color: kDark)),
      ]),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg = kDark;

    switch (status) {
      case 'Completed':
        bg = const Color(0xFF4CAF50); // green
        fg = Colors.white;
        break;
      case 'Pending':
        bg = const Color(0xFFFFF3CD); // soft amber
        fg = const Color(0xFF856404);
        break;
      case 'Delivered':
        bg = kPrimary;
        fg = kDark;
        break;
      case 'Pickup Soon':
        bg = kDark;
        fg = Colors.white;
        break;
      default:
        bg = Colors.white;
        fg = kDark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: kDark, width: 2),
        boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, color: fg, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Donation Tile ─────────────────────────────────────────────────────────────
class DonationTile extends StatelessWidget {
  final Donation donation;
  const DonationTile({super.key, required this.donation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kDark, width: 2),
        boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kCard,
            border: Border.all(color: kDark, width: 2),
            boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
          ),
          alignment: Alignment.center,
          child: Text(donation.type == 'clothes' ? '👕' : '✏️',
              style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(donation.category.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              donation.orgName ?? 'Searching for match...',
              style: const TextStyle(
                  fontSize: 11, color: kMuted, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
        StatusBadge(status: donation.status),
      ]),
    );
  }
}