import 'package:flutter_test/flutter_test.dart';
import 'package:pusa_mobile/pusa_app.dart';

void main() {
  testWidgets('Pusa preview opens with financial management dashboard and navigation', (tester) async {
    await tester.pumpWidget(const PusaApp(backendConfigured: false));

    expect(find.text('PUSA'), findsOneWidget);
    expect(find.text('Financial Management'), findsOneWidget);
    expect(find.text('Your financial workspace'), findsOneWidget);
    expect(find.textContaining('Preview mode.'), findsOneWidget);
    expect(find.text('Pockets'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
  });
}
