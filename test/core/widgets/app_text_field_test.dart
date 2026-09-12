import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/widgets/app_text_field.dart';

void main() {
  testWidgets('shows the label and reflects typed text via the controller', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(label: 'Email', controller: controller),
        ),
      ),
    );

    expect(find.text('Email'), findsOneWidget);

    await tester.enterText(find.byType(AppTextField), 'ahmed@example.com');

    expect(controller.text, 'ahmed@example.com');
  });

  testWidgets('obscures text when obscureText is true', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            label: 'Password',
            controller: controller,
            obscureText: true,
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
  });

  testWidgets('runs the validator and shows the returned error text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppTextField(
              label: 'Email',
              controller: controller,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Required' : null,
            ),
          ),
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
  });
}