import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdsb_eform/main.dart';

void main() {
  testWidgets('shows the missing-config screen when no Supabase credentials are supplied', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HdsbEformApp()));

    expect(find.text('Supabase credentials not set'), findsOneWidget);
  });
}
