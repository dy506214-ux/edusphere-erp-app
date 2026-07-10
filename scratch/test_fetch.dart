import 'package:http/http.dart' as http;

void main() async {
  final url1 = Uri.parse('https://edusphere-erp-frontend.onrender.com/api/uploads/avatars/1783671460922-81823266.png');
  final res1 = await http.get(url1);
  print('Get with /api status: ${res1.statusCode}');

  final url2 = Uri.parse('https://edusphere-erp-frontend.onrender.com/uploads/avatars/1783671460922-81823266.png');
  final res2 = await http.get(url2);
  print('Get without /api status: ${res2.statusCode}');
}
