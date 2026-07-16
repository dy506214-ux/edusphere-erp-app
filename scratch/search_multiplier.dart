void main() {
  int c = 20;
  for (int a = 0; a <= 100; a++) {
    for (int b = 0; b <= 100; b++) {
      if ((13 * a + b) % c == 1 && (1 * a + b) % c == 17) {
        print('Formula found for 20: (emailNumber * $a + $b) % 20 == RouteNumber');
      }
    }
  }
}
