// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_barbeiro/main.dart';

void main() {
  testWidgets('Abre tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const BarberApp());

    expect(find.text('G BARBER CLUB'), findsOneWidget);
    expect(find.text('Painel administrativo'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.text('Primeiro acesso? Cadastre-se'), findsOneWidget);
  });
}