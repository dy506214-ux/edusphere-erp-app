import 'package:flutter_test/flutter_test.dart';
import 'package:edusphere/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EduSphereApp());
    expect(find.byType(EduSphereApp), findsOneWidget);
  });
}
