import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/donation.dart';
import '../models/need.dart';
import '../models/user_profile.dart';
import '../theme.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_field.dart';
import '../widgets/widgets.dart';

class OrgHomeScreen extends StatefulWidget {
  final UserProfile user;
  final Future<void> Function() onChanged;
  final Future<void> Function() onSignOut;

  const OrgHomeScreen({
    super.key,
    required this.user,
    required this.onChanged,
    required this.onSignOut,
  });

  @override
  State<OrgHomeScreen> createState() => _OrgHomeScreenState();
}

class _OrgHomeScreenState extends State<OrgHomeScreen> {
  void _showAddNeedDialog() {
    showDialog(context: context, builder: (_) => _AddNeedDialog(user: widget.user));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kDark, width: 2))),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WELCOME',
                          style: GoogleFonts.spaceMono(
                              fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 13)),
                      Text(
                        widget.user.orgName ?? widget.user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cinzelDecorative(
                            fontSize: 28, fontWeight: FontWeight.w900, color: kDark),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 62, height: 62,
                  decoration: brutalBox(kPrimary),
                  alignment: Alignment.center,
                  child: Text(widget.user.fullName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(children: const [
                Expanded(child: StatCard(label: 'Items Received', value: '124', bg: kPrimary)),
                SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Donations', value: '0', bg: Colors.white)),
                SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Children Helped', value: '45', bg: Colors.white)),
              ]),
            ),

            // Post a Need button
            Padding(
              padding: const EdgeInsets.all(24),
              child: BrutalButton.primary(text: 'Post a New Need', onTap: _showAddNeedDialog),
            ),

            // Needs Board
            _SectionTitle(title: 'Needs Board'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('needs')
                  .where('orgId', isEqualTo: widget.user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final needs = snapshot.data?.docs
                        .map((e) => Need.fromMap(e.data(), e.id))
                        .toList() ??
                    [];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: needs.isEmpty
                      ? const EmptyBox(text: 'No needs posted yet.')
                      : Column(
                          children: needs
                              .map((n) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _NeedTile(need: n),
                                  ))
                              .toList(),
                        ),
                );
              },
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: 'Incoming Donations'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('orgId', isEqualTo: widget.user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final donations = snapshot.data?.docs
                        .map((e) => Donation.fromMap(e.data(), e.id))
                        .toList() ??
                    [];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: donations.isEmpty
                      ? const EmptyBox(text: 'No incoming donations yet.')
                      : Column(
                          children: donations
                              .map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: DonationTile(donation: d),
                                  ))
                              .toList(),
                        ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: BrutalButton.dark(
                  text: 'Sign Out', onTap: () async => widget.onSignOut()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Need Tile ─────────────────────────────────────────────────────────────────
class _NeedTile extends StatelessWidget {
  final Need need;
  const _NeedTile({required this.need});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: brutalBox(Colors.white),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(need.item.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Quantity: ${need.quantity}',
                style: const TextStyle(
                    fontSize: 11, color: kMuted, fontWeight: FontWeight.bold)),
          ]),
        ),
        IconButton(
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('needs')
                .doc(need.id)
                .delete();
          },
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ]),
    );
  }
}

// ── Add Need Dialog ────────────────────────────────────────────────────────────
class _AddNeedDialog extends StatefulWidget {
  final UserProfile user;
  const _AddNeedDialog({required this.user});

  @override
  State<_AddNeedDialog> createState() => _AddNeedDialogState();
}

class _AddNeedDialogState extends State<_AddNeedDialog> {
  final _item = TextEditingController();
  final _quantity = TextEditingController(text: '1');

  Future<void> _submit() async {
    await FirebaseFirestore.instance.collection('needs').add({
      'orgId': widget.user.uid,
      'orgName': widget.user.orgName ?? widget.user.fullName,
      'item': _item.text.trim(),
      'quantity': int.tryParse(_quantity.text) ?? 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: brutalBox(Colors.white, borderWidth: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Post a Need',
              style: GoogleFonts.anton(fontSize: 28, color: kDark)),
          const SizedBox(height: 16),
          BrutalField(controller: _item, hint: 'Item Name'),
          const SizedBox(height: 12),
          BrutalField(controller: _quantity, hint: 'Quantity Needed'),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: BrutalButton.outline(
                text: 'Cancel', onTap: () => Navigator.pop(context))),
            const SizedBox(width: 10),
            Expanded(child: BrutalButton.primary(text: 'Post Need', onTap: _submit)),
          ]),
        ]),
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Text(title.toUpperCase(),
          style: GoogleFonts.spaceMono(
              fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3)),
    );
  }
}