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
  'parent':     {'email': 'parent.smith@edusmart.edu',   'password': 'Parent@2024',     'name': 'Mr. Smith',         'subtitle': 'Parent of Alex Rivera'},
  'admin':      {'email': 'admin@edusmart.edu',          'password': 'Admin@2024',      'name': 'Dr. Sharma',        'subtitle': 'School Administrator'},
  'accountant': {'email': 'accounts@edusmart.edu',       'password': 'Account@2024',    'name': 'Ms. Priya',         'subtitle': 'Senior Accountant'},
  'transport':  {'email': 'transport@edusmart.edu',      'password': 'Transport@2024',  'name': 'Mr. Rajan',         'subtitle': 'Transport Manager'},
};
