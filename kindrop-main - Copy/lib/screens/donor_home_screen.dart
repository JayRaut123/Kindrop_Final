import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../kindrop_route.dart';
import '../models/donation.dart';
import '../models/user_profile.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'donate_selection_screen.dart';
import 'history_screen.dart';

class DonorHomeScreen extends StatelessWidget {
  final UserProfile user;
  const DonorHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final firstName = user.fullName.split(' ').first;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final donations = snapshot.data?.docs
                .map((e) => Donation.fromMap(e.data(), e.id))
                .toList() ??
            [];

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // Marquee ticker
            Container(
              color: kDark,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Text(
                '• URGENT: 500+ CHILDREN NEED SCHOOL SUPPLIES • DONATE CLOTHES FOR WINTER • YOUR IMPACT MATTERS • HELP SOMEONE TODAY •',
                style: GoogleFonts.spaceMono(
                    color: kPrimary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),

            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kDark, width: 2))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WELCOME',
                            style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                fontSize: 13)),
                        Text(
                          firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cinzelDecorative(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: kDark,
                              height: 1),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: brutalBox(kPrimary),
                      alignment: Alignment.center,
                      child: Text(
                        user.fullName[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(children: [
                Expanded(
                    child: StatCard(
                        label: 'Donations',
                        value: '${donations.length}',
                        bg: kPrimary)),
                const SizedBox(width: 12),
                const Expanded(
                    child: StatCard(label: 'Orgs Helped', value: '2', bg: Colors.white)),
                const SizedBox(width: 12),
                const Expanded(
                    child: StatCard(label: 'Lives Touched', value: '12', bg: Colors.white)),
              ]),
            ),

            // Donate Now card
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: brutalBox(kDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Someone needs your help today',
                      style: GoogleFonts.anton(
                          fontSize: 34, color: Colors.white, height: .95),
                    ),
                    const SizedBox(height: 10),
                    Text('Tap to make a difference 🤝',
                        style: GoogleFonts.spaceMono(
                            color: kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          KindropRoute(
                              builder: (_) =>
                                  DonateSelectionScreen(user: user))),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 20),
                        decoration: brutalBox(kPrimary),
                        child: Center(
                          child: Text('Donate Now',
                              style: TextStyle(
                                  color: kDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recent Activity header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(children: [
                Expanded(
                  child: Text('RECENT ACTIVITY',
                      style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      KindropRoute(
                          builder: (_) => HistoryScreen(user: user))),
                  child: const Text('View All',
                      style: TextStyle(color: kMuted)),
                ),
              ]),
            ),

            // Donations list
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              child: donations.isEmpty
                  ? const EmptyBox(
                      text: 'No donations yet.\nStart by helping someone today!')
                  : Column(
                      children: donations
                          .map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DonationTile(donation: d),
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}