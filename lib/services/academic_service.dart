import 'api_service.dart';

class AcademicService {
  AcademicService._privateConstructor();
  static final AcademicService instance = AcademicService._privateConstructor();

  Future<Map<String, dynamic>> getClasses() async {
    final response = await ApiService.instance.get('academic/classes');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSections({String? classId}) async {
    final queryParams = classId != null ? {'classId': classId} : null;
    final response = await ApiService.instance.get('academic/sections', queryParams: queryParams);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSubjects({String? classId}) async {
    final queryParams = classId != null ? {'classId': classId} : null;
    final response = await ApiService.instance.get('academic/subjects', queryParams: queryParams);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTimetables() async {
    final response = await ApiService.instance.get('academic/timetables');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTeacherTimetable(String teacherId) async {
    final response = await ApiService.instance.get('timetables/teacher/$teacherId');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentTimetable(String sectionId) async {
    final response = await ApiService.instance.get('timetables/student/$sectionId');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getActiveAnnouncements() async {
    final response = await ApiService.instance.get('announcements/active');
    return response as Map<String, dynamic>;
  }
}
