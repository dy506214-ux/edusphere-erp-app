class AppUser {
  final String name;
  final String email;
  final String role;
  final String subtitle;
  final String avatarSeed;

  const AppUser({
    required this.name,
    required this.email,
    required this.role,
    required this.subtitle,
    required this.avatarSeed,
  });
}

const Map<String, Map<String, String>> kCredentials = {
  'student':    {'email': 'alex.rivera@edusmart.edu',    'password': 'Student@2024',    'name': 'Alex Rivera',       'subtitle': 'Grade 12-A • Roll #24'},
  'teacher':    {'email': 'prof.harrison@edusmart.edu',  'password': 'Teacher@2024',    'name': 'Prof. Harrison',    'subtitle': 'HOD Physics Dept.'},
};
