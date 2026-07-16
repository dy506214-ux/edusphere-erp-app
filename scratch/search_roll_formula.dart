void main() {
  final mappings = {
    13: 1,  // Arjun Jain
    1: 17,  // Amit Das
    37: 12, // Vihaan Verma
    22: 14, // Dinesh Garg
    5: 19,  // Vivaan Das
    7: 2,   // Pooja Jain
  };

  print('Searching formulas modulo C:');
  for (int c = 15; c <= 30; c++) {
    for (int a = 0; a <= 150; a++) {
      for (int b = 0; b <= 150; b++) {
        bool ok = true;
        for (var entry in mappings.entries) {
          final res = (entry.key * a + b) % c;
          // We assume routes are 1-indexed. If route is between 1 and c, let's adjust.
          // In JavaScript: routeNumber = ((rollNumber * a + b) % c) + 1;
          // Let's test that exact formula!
          final routeNumber = ((entry.key * a + b) % c) + 1;
          if (routeNumber != entry.value) {
            ok = false;
            break;
          }
        }
        if (ok) {
          print('FOUND: routeNumber = ((rollNumber * $a + $b) % $c) + 1');
        }
      }
    }
  }
}
