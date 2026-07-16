int jsHashCode(String str) {
  int hash = 0;
  for (int i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.codeUnitAt(i);
    hash = hash & 0xFFFFFFFF; // 32-bit signed/unsigned integer
  }
  return hash;
}

void main() {
  final students = [
    {'first': 'Arjun', 'last': 'Jain', 'route': 1},
    {'first': 'Amit', 'last': 'Das', 'route': 17},
    {'first': 'Vihaan', 'last': 'Verma', 'route': 12},
    {'first': 'Dinesh', 'last': 'Garg', 'route': 14},
    {'first': 'Vivaan', 'last': 'Das', 'route': 19},
    {'first': 'Pooja', 'last': 'Jain', 'route': 2},
  ];

  const mod = 20;

  // Test full name, first name, last name with hashCode or char sum
  print('Searching name hash strategies:');
  for (int offset = -50; offset <= 50; offset++) {
    // Strategy A: full name hashCode
    bool okA = true;
    for (var s in students) {
      final name = '${s['first']} ${s['last']}';
      final h = jsHashCode(name).abs();
      if (((h + offset) % mod) + 1 != s['route']) {
        okA = false;
        break;
      }
    }
    if (okA) {
      print('FOUND Strategy A: (hashCode(fullName) + $offset) % 20 + 1');
    }

    // Strategy B: sum of char codes of full name
    bool okB = true;
    for (var s in students) {
      final name = '${s['first']} ${s['last']}';
      int sum = 0;
      for (int i = 0; i < name.length; i++) {
        sum += name.codeUnitAt(i);
      }
      if (((sum + offset) % mod) + 1 != s['route']) {
        okB = false;
        break;
      }
    }
    if (okB) {
      print('FOUND Strategy B: (sumChar(fullName) + $offset) % 20 + 1');
    }

    // Strategy C: first name only hashCode
    bool okC = true;
    for (var s in students) {
      final name = s['first'] as String;
      final h = jsHashCode(name).abs();
      if (((h + offset) % mod) + 1 != s['route']) {
        okC = false;
        break;
      }
    }
    if (okC) {
      print('FOUND Strategy C: (hashCode(firstName) + $offset) % 20 + 1');
    }

    // Strategy D: first name sum of char codes
    bool okD = true;
    for (var s in students) {
      final name = s['first'] as String;
      int sum = 0;
      for (int i = 0; i < name.length; i++) {
        sum += name.codeUnitAt(i);
      }
      if (((sum + offset) % mod) + 1 != s['route']) {
        okD = false;
        break;
      }
    }
    if (okD) {
      print('FOUND Strategy D: (sumChar(firstName) + $offset) % 20 + 1');
    }
  }
}
