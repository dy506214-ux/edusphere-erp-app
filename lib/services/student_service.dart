import 'api_service.dart';

class StudentService {
  StudentService._privateConstructor();
  static final StudentService instance = StudentService._privateConstructor();

  Future<Map<String, dynamic>> getStudentProfile() async {
    final response = await ApiService.instance.get('students/me');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudents({
    String? classId,
    String? sectionId,
    String? status,
    String? search,
  }) async {
    final queryParams = {
      if (classId != null && classId.isNotEmpty) 'classId': classId,
      if (sectionId != null && sectionId.isNotEmpty) 'sectionId': sectionId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': '500',
    };
    final response = await ApiService.instance.get('students', queryParams: queryParams);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentDocuments(String studentId) async {
    final response = await ApiService.instance.get('students/$studentId/documents');
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadStudentDocument({
    required String studentId,
    required List<int> fileBytes,
    required String fileName,
    required String documentType,
    required String documentName,
  }) async {
    final response = await ApiService.instance.multipartRequest(
      'POST',
      'students/$studentId/documents',
      fileKey: 'file',
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {
        'documentType': documentType,
        'documentName': documentName,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteStudentDocument(String documentId) async {
    final response = await ApiService.instance.delete('students/documents/$documentId');
    return response as Map<String, dynamic>;
  }
}
