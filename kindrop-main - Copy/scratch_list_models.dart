import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'AIzaSyBTnOm_-hzEK-ihX392zl9JQv_WIfS42gY'; // User's latest key from their edit
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=' + apiKey);
  
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final models = data['models'] as List;
    for (var model in models) {
      if (model['name'].contains('gemini')) print(model['name']);
    }
  } else {
    print('Failed to load models: ' + response.statusCode.toString() + ' - ' + response.body);
  }
}
