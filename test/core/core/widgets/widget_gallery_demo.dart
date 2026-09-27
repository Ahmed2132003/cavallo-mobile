import 'package:flutter/material.dart';

import 'app_button.dart';
import 'app_text_field.dart';
import 'empty_state_widget.dart';
import 'error_state_widget.dart';
import 'loading_indicator.dart';

/// TEMPORARY — DELETE ME once real feature screens exist.
///
/// Part P-006's acceptance criteria calls for "a demo screen (temporary,
/// deletable) [that] renders all five widgets correctly." This is that
/// screen. It exists only so the widget test in
/// test/core/widgets/widget_gallery_demo_test.dart (and anyone running
/// the app manually) can confirm every shared widget renders correctly
/// together under the app theme before any real feature is built on top
/// of them.
///
/// It is deliberately NOT wired into `lib/main.dart` or any route —
/// routing is out of scope for this part — and should be deleted the
/// moment a real feature screen exists to demonstrate these widgets in
/// context instead.
class WidgetGalleryDemo extends StatefulWidget {
  const WidgetGalleryDemo({super.key});

  @override
  State<WidgetGalleryDemo> createState() => _WidgetGalleryDemoState();
}

class _WidgetGalleryDemoState extends State<WidgetGalleryDemo> {
  final _controller = TextEditingController();
  bool _buttonLoading = false;
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared Widgets Demo (P-006)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'AppButton',
              isLoading: _buttonLoading,
              onPressed: () {
                setState(() => _buttonLoading = true);
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) setState(() => _buttonLoading = false);
                });
              },
            ),
            const SizedBox(height: 16),
            AppTextField(label: 'AppTextField', controller: _controller),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() => _showError = !_showError),
              child: Text(
                _showError ? 'Show empty state' : 'Show error state',
              ),
            ),
            const SizedBox(height: 16),
            _showError
                ? ErrorStateWidget(
                    message: 'Something went wrong.',
                    onRetry: () {},
                  )
                : const EmptyStateWidget(
                    message: 'Nothing here yet.',
                    icon: Icons.inbox_outlined,
                  ),
            const SizedBox(height: 16),
            const SizedBox(height: 80, child: LoadingIndicator()),
          ],
        ),
      ),
    );
  }
}