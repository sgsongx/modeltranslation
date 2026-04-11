import 'package:flutter_test/flutter_test.dart';
import 'package:modeltranslation/main.dart';

void main() {
  testWidgets('App shell shows the translation workspace', (WidgetTester tester) async {
    await tester.pumpWidget(const ModelTranslationApp());

    expect(find.text('Model Translation'), findsOneWidget);
    expect(find.text('Core contracts ready.'), findsOneWidget);
  });
}