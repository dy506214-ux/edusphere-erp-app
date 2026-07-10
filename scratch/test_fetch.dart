import 'package:http/http.dart' as http;

void main() async {
  final url1 = Uri.parse('https://edusphere-erp-frontend.onrender.com/uploads/avatars/1783670325370-672408785.jpg');
  final res1 = await http.get(url1);
  print('Get url1 status: ${res1.statusCode}, bytes: ${res1.bodyBytes.length}');

  final url2 = Uri.parse('https://edusphere-erp-frontend.onrender.com/uploads/avatars/1783671460922-81823266.png');
  final res2 = await http.get(url2);
  print('Get url2 status: ${res2.statusCode}, bytes: ${res2.bodyBytes.length}');
}
