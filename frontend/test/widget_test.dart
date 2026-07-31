import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kickoff/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const KickoffApp());

    // Verify that the splash or landing page loads.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

