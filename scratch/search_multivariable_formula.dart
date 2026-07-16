void main() {
  // Map Section name to integer code
  int getSectionCode(String sec) {
    return sec.codeUnitAt(0) - 'A'.codeUnitAt(0); // A=0, B=1, C=2, etc.
  }

  // Data points:
  // [rollNumber, classVal, sectionCode] -> RouteNumber
  final data = [
    [13, 2, getSectionCode('A'), 1],   // Arjun Jain
    [1, 0, getSectionCode('A'), 17],   // Amit Das
    [37, 12, getSectionCode('E'), 12], // Vihaan Verma
    [22, 10, getSectionCode('B'), 14], // Dinesh Garg
    [5, 2, getSectionCode('C'), 19],   // Vivaan Das
    [7, 2, getSectionCode('E'), 2],    // Pooja Jain
  ];

  print('Searching multivariable modulo formulas:');
  const mod = 20;

  for (int a = 0; a < mod; a++) {
    for (int b = 0; b < mod; b++) {
      for (int c = 0; c < mod; c++) {
        for (int d = 0; d < mod; d++) {
          bool ok = true;
          for (var pt in data) {
            final roll = pt[0];
            final cls = pt[1];
            final sec = pt[2];
            final expectedRoute = pt[3];
            
            final routeVal = ((roll * a + cls * b + sec * c + d) % mod) + 1;
            if (routeVal != expectedRoute) {
              ok = false;
              break;
            }
          }
          if (ok) {
            print('FOUND FORMULA: routeNumber = ((rollNumber * $a + classVal * $b + sectionCode * $c + $d) % 20) + 1');
          }
        }
      }
    }
  }
}
