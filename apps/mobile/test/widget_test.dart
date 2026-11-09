import 'package:flutter_test/flutter_test.dart';
import 'package:pusa_mobile/pusa_app.dart';

void main() {
  testWidgets('Pusa preview opens with dashboard and navigation', (tester) async {
    await tester.pumpWidget(const PusaApp(backendConfigured: false));

    expect(find.text('PUSA'), findsOneWidget);
    expect(find.text('Let’s put your money to work.'), findsOneWidget);
    expect(find.text('Preview mode is active.'), findsOneWidget);
    expect(find.text('Pockets'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
  });
}
