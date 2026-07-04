int naturalCompare(String a, String b) {
  final regExp = RegExp(r'(\d+)|(\D+)');
  final matchesA = regExp.allMatches(a.toLowerCase()).toList();
  final matchesB = regExp.allMatches(b.toLowerCase()).toList();

  int i = 0;
  while (i < matchesA.length && i < matchesB.length) {
    final mA = matchesA[i].group(0)!;
    final mB = matchesB[i].group(0)!;

    final numA = int.tryParse(mA);
    final numB = int.tryParse(mB);

    if (numA != null && numB != null) {
      final comp = numA.compareTo(numB);
      if (comp != 0) return comp;
    } else {
      final comp = mA.compareTo(mB);
      if (comp != 0) return comp;
    }
    i++;
  }
  return matchesA.length.compareTo(matchesB.length);
}

void main() {
  final emails = [
    'student100@edusphere.com',
    'student2@edusphere.com',
    'student1@edusphere.com',
    'student10@edusphere.com',
    'student11@edusphere.com',
    'student3@edusphere.com',
    'sample@gmail.com',
    'student.1781594786255@school.local',
    'student.1781593071797@school.local',
  ];

  emails.sort(naturalCompare);
  print('Sorted emails:');
  for (var email in emails) {
    print(email);
  }
}
