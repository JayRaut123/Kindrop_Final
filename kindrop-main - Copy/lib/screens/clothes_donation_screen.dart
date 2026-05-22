import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_profile.dart';
import '../theme.dart';
import '../widgets/brutal_button.dart';
import '../widgets/brutal_field.dart';
import '../widgets/widgets.dart';
import '../main.dart'; // import to get kCloudflareUrl
import '../config.dart'; // centralized API key

class ClothesDonationScreen extends StatefulWidget {
  final UserProfile user;
  const ClothesDonationScreen({super.key, required this.user});

  @override
  State<ClothesDonationScreen> createState() => _ClothesDonationScreenState();
}

class _ClothesDonationScreenState extends State<ClothesDonationScreen> {
  bool _loading = false;
  String _category = 'Kids Clothes';
  String _condition = 'New';
  final _quantity = TextEditingController(text: '1');
  final _address = TextEditingController();
  DateTime? _pickupDate;

  // AI Quality Check
  File? _clotheImage;
  String _qualityResult = '';
  bool _qualityLoading = false;
  bool _qualityPassed = false;
  bool _quotaExceeded = false;

  final List<String> _categories = [
    'Kids Clothes',
    'Adult Clothes',
    'Winter Clothes',
    'Summer Clothes',
    'Mixed',
  ];

  Future<void> _pickAndVerify({bool fromGallery = false}) async {
    final picked = await ImagePicker().pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() {
      _clotheImage = File(picked.path);
      _qualityLoading = true;
      _qualityResult = '';
      _qualityPassed = false;
    });

    try {
      final model = GenerativeModel(
        model: KindropConfig.geminiModel,
        apiKey: KindropConfig.geminiApiKey,
      ); //done

      final imageBytes = await _clotheImage!.readAsBytes();
      // Detect MIME type from file extension for accuracy
      final ext = picked.path.toLowerCase().split('.').last;
      final mimeType = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';

      final prompt = TextPart(
        'Look at this clothing item. Is it in good condition suitable for donation to a charity? '
        'Answer strictly starting with either "\u2705 Good Quality - Suitable for donation" '
        'or "\u274c Poor Quality - Not suitable for donation". '
        'Then give one short specific reason (max 15 words).',
      );
      final imagePart = DataPart(mimeType, imageBytes);
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final result = response.text ?? 'Could not analyze image.';
      if (!mounted) return;
      setState(() {
        _qualityResult = result;
        _qualityPassed = result.contains('\u2705');
        _quotaExceeded = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString();
      final isQuota = errStr.contains('quota') ||
          errStr.contains('RESOURCE_EXHAUSTED') ||
          errStr.contains('429');
      setState(() {
        _quotaExceeded = isQuota;
        if (isQuota) {
          _qualityResult = '\u26a0\ufe0f API key quota exceeded. To fix: go to aistudio.google.com, '
              'create a new free API key, and update lib/config.dart. '
              'You can also use the Skip button below.';
        } else {
          _qualityResult = 'Error analyzing image. Try retaking or picking from gallery.';
        }
        _qualityPassed = false;
      });
    } finally {
      if (mounted) setState(() => _qualityLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_qualityPassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify clothing quality first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final docRef = await FirebaseFirestore.instance.collection('donations').add({
        'donorId': widget.user.uid,
        'donorName': widget.user.fullName,
        'type': 'clothes',
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
          Text('Donate Clothes 👕',
              style: GoogleFonts.anton(fontSize: 32, color: kDark)),
          const SizedBox(height: 6),
          Text('Fill in the details below',
              style: GoogleFonts.spaceMono(
                  fontWeight: FontWeight.bold, color: kMuted)),
          const SizedBox(height: 24),

          // ── AI Quality Check ──────────────────────────────────────
          const FieldLabel(text: 'AI Quality Verification'),
          GestureDetector(
            onTap: _pickAndVerify,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: kCard,
                border: Border.all(color: kDark, width: 2),
                boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
              ),
              child: _clotheImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, size: 48, color: kMuted),
                        const SizedBox(height: 8),
                        Text('Tap to take photo of clothing',
                            style: GoogleFonts.spaceMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kMuted)),
                      ],
                    )
                  : Image.file(_clotheImage!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),

          // Quality result
          if (_qualityLoading)
            const Center(child: CircularProgressIndicator(color: kDark))
          else if (_qualityResult.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _qualityPassed ? kPrimary : Colors.red[100],
                border: Border.all(color: kDark, width: 2),
                boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
              ),
              child: Text(_qualityResult,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),

          if (_clotheImage != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickAndVerify,
              child: Text('↩ Retake photo',
                  style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: kMuted,
                      decoration: TextDecoration.underline)),
            ),
          ],

          // Always-visible skip button
          const SizedBox(height: 12),
          if (!_qualityPassed)
            GestureDetector(
              onTap: () => setState(() {
                _qualityPassed = true;
                _quotaExceeded = false;
                _qualityResult = '✅ Manually approved — AI check skipped.';
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange.shade700, width: 2),
                  boxShadow: [BoxShadow(color: Colors.orange.shade300, offset: const Offset(3, 3))],
                ),
                child: Center(
                  child: Text('⚡ Skip AI Check / Mark as Good',
                      style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900])),
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Category
          const FieldLabel(text: 'Type of clothes'),
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
          const FieldLabel(text: 'Number of items'),
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