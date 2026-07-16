void main() {
  final mappings = {
    25012: 1,
    25000: 17,
    26549: 12,
    27439: 14,
    20804: 18,
    27699: 5,
    29350: 19,
    29414: 2,
    29983: 5,
  };

  print('Searching for simple modulo formulas:');
  // Let's test: (adm % C) + D
  for (int c = 1; c <= 100; c++) {
    for (int d = -50; d <= 50; d++) {
      bool ok = true;
      for (var entry in mappings.entries) {
        final res = (entry.key % c) + d;
        if (res != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) {
        print('Found simple formula: (admissionNumber % $c) + $d');
      }
    }
  }

  // Let's test: ((adm * A) % C) + D
  for (int c = 15; c <= 30; c++) {
    for (int a = 1; a <= 100; a++) {
      for (int d = -5; d <= 5; d++) {
        bool ok = true;
        for (var entry in mappings.entries) {
          final res = ((entry.key * a) % c) + d;
          if (res != entry.value) {
            ok = false;
            break;
          }
        }
        if (ok) {
          print('Found multiplier formula: ((admissionNumber * $a) % $c) + $d');
        }
      }
    }
  }

  // Let's test: (adm % 20) based hashing or custom logic
  // What about: using string operations?
  // Let's check last digits or string hash code
  print('\nTesting string hashcode mod 20:');
  for (int c = 10; c <= 50; c++) {
    for (int d = -5; d <= 5; d++) {
      bool ok = true;
      for (var entry in mappings.entries) {
        final str = 'ADM-${entry.key}';
        final hash = str.hashCode.abs();
        final res = (hash % c) + d;
        if (res != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) {
        print('Found String hashCode formula: (str.hashCode.abs() % $c) + $d');
      }
    }
  }
}
