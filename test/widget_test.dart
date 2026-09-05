import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nerdmaxxing_client/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const NerdMaxxingApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

