import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';

class QualityCheckScreen extends StatefulWidget {
  const QualityCheckScreen({super.key});

  @override
  State<QualityCheckScreen> createState() => _QualityCheckScreenState();
}

class _QualityCheckScreenState extends State<QualityCheckScreen> {
  File? _image;
  String _result = '';
  bool _loading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _image = File(picked.path));
      _analyzeImage(File(picked.path));
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: 'AIzaSyBTnOm_-hzEK-ihX392zl9JQv_WIfS42gY', // paste your key here
      );

      final imageBytes = await imageFile.readAsBytes();
      final prompt = TextPart(
          'Look at this clothing item. Is it in good condition suitable for donation? '
          'Answer in one line: either "✅ Good Quality - Suitable for donation" '
          'or "❌ Poor Quality - Not suitable for donation". '
          'Then give one sentence reason why.');

      final imagePart = DataPart('image/jpeg', imageBytes);
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      setState(() => _result = response.text ?? 'Could not analyze image');
    } catch (e) {
      setState(() => _result = 'Error: ${e.toString()}');
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
        title: const Text('Quality Check',
            style: TextStyle(color: kDark, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SCAN CLOTHING QUALITY',
                style: TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 20),

            // Image preview
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: kCard,
                  border: Border.all(color: kDark, width: 2),
                  boxShadow: const [
                    BoxShadow(color: kDark, offset: Offset(4, 4))
                  ],
                ),
                child: _image == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 52, color: kMuted),
                          SizedBox(height: 12),
                          Text('Tap to take photo',
                              style: TextStyle(
                                  color: kMuted, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Image.file(_image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),

            // Result box
            if (_loading)
              const Center(child: CircularProgressIndicator(color: kDark))
            else if (_result.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _result.contains('✅') ? kPrimary : Colors.red[100],
                  border: Border.all(color: kDark, width: 2),
                  boxShadow: const [
                    BoxShadow(color: kDark, offset: Offset(4, 4))
                  ],
                ),
                child: Text(_result,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),

            const SizedBox(height: 20),

            // Retake button
            if (_image != null)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: kDark,
                    border: Border.all(color: kDark, width: 2),
                    boxShadow: const [
                      BoxShadow(color: kDark, offset: Offset(4, 4))
                    ],
                  ),
                  child: const Center(
                    child: Text('Retake Photo',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}