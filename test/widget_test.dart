import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/helper/keyboard.dart';

void main() {
  testWidgets('KeyboardUtil.hideKeyboard removes focus', (WidgetTester tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(focusNode: focusNode),
                ElevatedButton(
                  onPressed: () => KeyboardUtil.hideKeyboard(context),
                  child: const Text('Hide'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Hide'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    focusNode.dispose();
  });
}
