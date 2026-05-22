import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/donation.dart';
import '../models/user_profile.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

class HistoryScreen extends StatelessWidget {
  final UserProfile user;
  const HistoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final donations = snapshot.data?.docs
                .map((e) => Donation.fromMap(e.data(), e.id))
                .toList() ??
            [];

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Back + Title row
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.canPop(context)
                    ? Navigator.pop(context)
                    : null,
                child: Container(
                  width: 48, height: 48,
                  decoration: brutalBox(Colors.white),
                  child: const Icon(Icons.arrow_back, color: kDark),
                ),
              ),
              const SizedBox(width: 16),
              Text('Activity History',
                  style: GoogleFonts.anton(fontSize: 28, color: kDark)),
            ]),
            const SizedBox(height: 18),

            // Filter chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['All', 'Clothes', 'Stationery', 'Food']
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: brutalBox(Colors.white, borderWidth: 2),
                        child: Text(f.toUpperCase(),
                            style: GoogleFonts.spaceMono(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),

            if (donations.isEmpty)
              const EmptyBox(text: 'No history found')
            else
              ...donations.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: brutalBox(Colors.white),
                      child: Column(children: [
                        Row(children: [
                          Container(
                            width: 58, height: 58,
                            decoration: brutalBox(kCard),
                            alignment: Alignment.center,
                            child: Text(
                              d.type == 'clothes' ? '👕' : '✏️',
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.category.toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    d.orgName ?? 'Processing...',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: kMuted,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ]),
                          ),
                          StatusBadge(status: d.status),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.calendar_today,
                              size: 12, color: kMuted),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(
                                DateTime.tryParse(d.createdAt) ??
                                    DateTime.now()),
                            style: const TextStyle(
                                fontSize: 11,
                                color: kMuted,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.filter_list,
                              size: 12, color: kMuted),
                          const SizedBox(width: 4),
                          Text(d.type.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                  )),
          ],
        );
      },
    );
  }
}