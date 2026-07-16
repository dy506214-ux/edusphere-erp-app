void main() {
  final mappings = {
    25012: 1,  // Arjun Jain
    25000: 17, // Amit Das
    26549: 12, // Vihaan Verma
    27439: 14, // Dinesh Garg
    29350: 19, // Vivaan Das
    29414: 2,  // Pooja Jain
  };

  print('Searching formulas modulo C on admission number values:');
  for (int c = 15; c <= 30; c++) {
    for (int a = 0; a <= 150; a++) {
      for (int b = 0; b <= 150; b++) {
        bool ok = true;
        for (var entry in mappings.entries) {
          final routeNumber = ((entry.key * a + b) % c) + 1;
          if (routeNumber != entry.value) {
            ok = false;
            break;
          }
        }
        if (ok) {
          print('FOUND: routeNumber = ((admissionNumber * $a + $b) % $c) + 1');
        }
      }
    }
  }
}
