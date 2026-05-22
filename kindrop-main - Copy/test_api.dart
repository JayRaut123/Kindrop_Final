import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final apiKey = '_Encrypted_by_Jay_';
  
  final modelsToTest = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-3.1-flash-lite-preview'
  ];

  for (final modelName in modelsToTest) {
    print('Testing model: $modelName');
    try {
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final prompt = TextPart('Are you there? Answer yes or no.');
      final response = await model.generateContent([Content.text('Are you there? Answer yes or no.')]);
      print('SUCCESS $modelName: ${response.text}');
    } catch (e) {
      print('ERROR $modelName: $e');
    }
    print('------------------------');
  }
}
