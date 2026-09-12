import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/error_reporting.dart';

void main() {
  test('reportError does not throw for a normal error/stack pair', () {
    expect(
      () => reportError(Exception('boom'), StackTrace.current),
      returnsNormally,
    );
  });

  test('reportError does not throw with an empty stack trace', () {
    expect(
      () => reportError('some non-Exception error object', StackTrace.empty),
      returnsNormally,
    );
  });
}