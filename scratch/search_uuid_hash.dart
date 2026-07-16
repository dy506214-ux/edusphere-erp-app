import 'dart:convert';

void main() {
  final mappings = {
    '26641bbf-bf4e-4bb1-842b-a74a7d7b96c8': 1,  // Arjun Jain
    '68ec8420-e4ae-42b0-96e5-9b68ef00d831': 17, // Amit Das
    '28925114-b396-4be3-a919-2d17f003a387': 12, // Vihaan Verma
    '9ce06364-e8fb-4ad5-bd4d-2c73ba8f2fe5': 14, // Dinesh Garg
    'fb2fa58b-e8cd-482a-869a-166d08eced3c': 19, // Vivaan Das
    '6f77c6ab-b03d-4c47-acd6-c37213d523db': 2,  // Pooja Jain
  };

  const mod = 20;

  // Strategy 1: Sum of char codes mod 20 + 1
  {
    for (int offset = -20; offset <= 20; offset++) {
      bool ok = true;
      for (var entry in mappings.entries) {
        int sum = 0;
        for (int i = 0; i < entry.key.length; i++) {
          sum += entry.key.codeUnitAt(i);
        }
        final res = ((sum + offset) % mod) + 1;
        if (res != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) {
        print('Found Strategy 1: (sumOfCharCodes + $offset) % 20 + 1');
      }
    }
  }

  // Strategy 2: Hash of the numeric digits only
  {
    for (int offset = -20; offset <= 20; offset++) {
      bool ok = true;
      for (var entry in mappings.entries) {
        int sum = 0;
        for (int i = 0; i < entry.key.length; i++) {
          final ch = entry.key[i];
          final digit = int.tryParse(ch);
          if (digit != null) {
            sum += digit;
          }
        }
        final res = ((sum + offset) % mod) + 1;
        if (res != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) {
        print('Found Strategy 2: (sumOfDigits + $offset) % 20 + 1');
      }
    }
  }

  // Strategy 3: hashCode of the string mod 20 + 1
  // Note: Dart's hashCode is platform-dependent, but JS's standard string hash is:
  // hash = 0; for (char in str) hash = (hash << 5) - hash + char;
  int jsHashCode(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = (hash << 5) - hash + str.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF; // 32-bit integer
    }
    return hash;
  }

  {
    for (int offset = -20; offset <= 20; offset++) {
      bool ok = true;
      for (var entry in mappings.entries) {
        final hash = jsHashCode(entry.key).abs();
        final res = ((hash + offset) % mod) + 1;
        if (res != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) {
        print('Found Strategy 3: (jsHashCode(uuid) + $offset) % 20 + 1');
      }
    }
  }
}
