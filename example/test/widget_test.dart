import 'package:flutter_test/flutter_test.dart';

import 'package:opensubtitles_hasher_example/main.dart';

void main() {
  testWidgets('Example app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('opensubtitles_hasher'), findsOneWidget);
  });
}
