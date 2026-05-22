import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyBTnOm_-hzEK-ihX392zl9JQv_WIfS42gY';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  
  try {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(url);
    final response = await request.close();
    
    final responseBody = await response.transform(utf8.decoder).join();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    
    if (json.containsKey('models')) {
      for (var model in json['models']) {
        final name = model['name'];
        final supportedOptions = model['supportedGenerationMethods']?.join(', ') ?? '';
        print('Model: $name \t Methods: $supportedOptions');
      }
    } else {
      print('Response: $responseBody');
    }
  } catch (e) {
    print('Failed: $e');
  }
}
