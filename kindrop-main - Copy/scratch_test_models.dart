import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = '_Encrypted_by_Jay_';
  final models = ['gemini-2.5-flash', 'gemini-flash-latest', 'gemini-2.0-flash-lite', 'gemini-2.5-pro'];
  
  for (var model in models) {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/' + model + ':generateContent?key=' + apiKey);
    
    final payload = jsonEncode({
      "contents": [{
        "parts": [{"text": "Hello"}]
      }]
    });
    
    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: payload);
    print('Testing ' + model + ' -> Status: ' + response.statusCode.toString());
    if (response.statusCode != 200) {
      print(response.body);
    } else {
      print('SUCCESS!');
    }
    print('---');
  }
}
