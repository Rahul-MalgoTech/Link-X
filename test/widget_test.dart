import 'package:bossy/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bossy login flow opens phone option screen', (tester) async {
    await tester.pumpWidget(const MyApp(showSplash: false));

    expect(find.text('Find your\nPerfect Match'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login_cta_button')));
    await tester.pumpAndSettle();

    expect(find.text('Use Phone Number'), findsOneWidget);
    expect(find.text('Login With Google'), findsOneWidget);
  });
}
