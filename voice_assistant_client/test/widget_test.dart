import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_client/main.dart';

void main() {
  testWidgets('VoiceAssistantApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceAssistantApp());
  });
}

