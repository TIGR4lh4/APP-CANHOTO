import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/main.dart'; // <-- esse é o nome que bate com o pubspec.yaml

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Constrói o app e dispara um frame
    await tester.pumpWidget(const MyApp());

    // Verifica se o contador começa em 0
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Clica no botão "+" e dispara um frame
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verifica se o contador foi incrementado
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
