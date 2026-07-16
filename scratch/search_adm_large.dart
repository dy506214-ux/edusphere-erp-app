void main() {
  final mappings = {
    25012: 1,  // Arjun Jain
    25000: 17, // Amit Das
    26549: 12, // Vihaan Verma
    27439: 14, // Dinesh Garg
    29350: 19, // Vivaan Das
    29414: 2,  // Pooja Jain
  };

  const c = 20;
  print('Searching formulas modulo 20 with larger multipliers/addends:');

  for (int a = 0; a <= 10000; a++) {
    for (int b = 0; b <= 1000; b++) {
      bool ok = true;
      for (var entry in mappings.entries) {
        final routeVal = ((entry.key * a + b) % c) + 1;
        if (routeVal != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) {
        print('FOUND: routeNumber = ((admissionNumber * $a + $b) % 20) + 1');
      }
    }
  }
}
