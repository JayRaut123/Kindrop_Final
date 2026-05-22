import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; // import to get kCloudflareUrl

import '../models/user_profile.dart';
import '../theme.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_field.dart';
import '../widgets/widgets.dart';

class StationeryDonationScreen extends StatefulWidget {
  final UserProfile user;
  const StationeryDonationScreen({super.key, required this.user});

  @override
  State<StationeryDonationScreen> createState() =>
      _StationeryDonationScreenState();
}

class _StationeryDonationScreenState extends State<StationeryDonationScreen> {
  bool _loading = false;
  String _category = 'Notebooks';
  String _condition = 'New';
  final _quantity = TextEditingController(text: '1');
  final _address = TextEditingController();
  DateTime? _pickupDate;

  final List<String> _categories = [
    'Notebooks',
    'Pens & Pencils',
    'School Kit',
    'Art Supplies',
    'Mixed',
  ];

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final docRef = await FirebaseFirestore.instance.collection('donations').add({
        'donorId': widget.user.uid,
        'donorName': widget.user.fullName,
        'type': 'stationery',
        'category': _category,
        'quantity': int.tryParse(_quantity.text) ?? 1,
        'condition': _condition,
        'address': _address.text.trim(),
        'pickupDate': _pickupDate?.toIso8601String() ?? '',
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
      final renderUrl = Uri.parse('$kCloudflareUrl/donate.html?fid=${docRef.id}');
      await launchUrl(renderUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Donate Stationery ✏️',
              style: GoogleFonts.anton(fontSize: 32, color: kDark)),
          const SizedBox(height: 6),
          Text('Fill in the details below',
              style: GoogleFonts.spaceMono(
                  fontWeight: FontWeight.bold, color: kMuted)),
          const SizedBox(height: 24),

          // Category
          const FieldLabel(text: 'Type of stationery'),
          Container(
            decoration: brutalBox(Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                items: _categories
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quantity
          const FieldLabel(text: 'Number of items/kits'),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: brutalInputDecoration(),
          ),
          const SizedBox(height: 16),

          // Condition
          const FieldLabel(text: 'Condition'),
          Row(children: [
            Expanded(child: _ConditionChip(
              text: 'New',
              active: _condition == 'New',
              onTap: () => setState(() => _condition = 'New'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ConditionChip(
              text: 'Gently Used',
              active: _condition == 'Gently Used',
              onTap: () => setState(() => _condition = 'Gently Used'),
            )),
          ]),
          const SizedBox(height: 16),

          // Address
          const FieldLabel(text: 'Pickup address'),
          TextField(
            controller: _address,
            maxLines: 4,
            decoration: brutalInputDecoration(hint: 'Enter your full address'),
          ),
          const SizedBox(height: 16),

          // Pickup date
          const FieldLabel(text: 'Preferred pickup date'),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime(2035),
                initialDate: DateTime.now(),
              );
              if (picked != null) setState(() => _pickupDate = picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: brutalBox(Colors.white),
              child: Text(
                _pickupDate == null
                    ? 'Select Date'
                    : DateFormat('dd MMM yyyy').format(_pickupDate!),
                style: GoogleFonts.spaceMono(),
              ),
            ),
          ),
          const SizedBox(height: 28),

          BrutalButton.primary(
            text: _loading ? 'Submitting...' : 'Submit Donation 🤝',
            onTap: _loading ? null : _submit,
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _ConditionChip(
      {required this.text, required this.active, required this.onTap});

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
                  color: active ? kDark : kMuted,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}