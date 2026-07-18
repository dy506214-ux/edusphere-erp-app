import 'api_service.dart';

class TeacherService {
  TeacherService._privateConstructor();
  static final TeacherService instance = TeacherService._privateConstructor();

  Future<Map<String, dynamic>> getTeacherProfile() async {
    final response = await ApiService.instance.get('teachers', queryParams: {'limit': '1000'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTeacherProfileById(String teacherId) async {
    final response = await ApiService.instance.get('teachers/$teacherId');
    return response as Map<String, dynamic>;
  }
}
