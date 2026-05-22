import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../kindrop_route.dart';
import '../models/user_profile.dart';
import '../theme.dart';
import 'clothes_donation_screen.dart';
import 'stationery_donation_screen.dart';

class DonateSelectionScreen extends StatelessWidget {
  final UserProfile user;
  const DonateSelectionScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: kDark),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you\nlike to donate? 🎁',
              style: GoogleFonts.anton(fontSize: 42, color: kDark, height: .9),
            ),
            const SizedBox(height: 32),

            _DonateOption(
              emoji: '👕',
              title: 'Donate Clothes',
              subtitle: 'Help keep them warm',
              bg: kPrimary,
              onTap: () => Navigator.push(
                context,
                KindropRoute(
                    builder: (_) => ClothesDonationScreen(user: user)),
              ),
            ),
            const SizedBox(height: 20),

            _DonateOption(
              emoji: '✏️',
              title: 'Donate Stationery',
              subtitle: 'Help them study & grow',
              bg: kCard,
              onTap: () => Navigator.push(
                context,
                KindropRoute(
                    builder: (_) => StationeryDonationScreen(user: user)),
              ),
            ),

            const Spacer(),

            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('Maybe Later',
                      style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: kMuted)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonateOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bg;
  final VoidCallback onTap;

  const _DonateOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: brutalBox(bg, borderWidth: 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.anton(fontSize: 28, color: kDark)),
              Text(subtitle,
                  style: GoogleFonts.spaceMono(
                      fontSize: 11, fontWeight: FontWeight.bold, color: kMuted)),
            ]),
          ),
          Container(
            width: 52, height: 52,
            decoration: brutalBox(kDark),
            child: const Icon(Icons.arrow_forward, color: Colors.white),
          ),
        ]),
      ),
    );
  }
}