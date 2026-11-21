import '../../../../core/network/api_failure.dart';
import '../../../../l10n/app_localizations.dart';

/// A user-facing, localized message for a failed Orders request.
/// Network failures and unknown failures are localized; a validation
/// failure shows the server's own field message (it names the real reason,
/// e.g. "not your product").
String orderErrorText(AppLocalizations l10n, Object error) {
  if (error is NetworkFailure) return l10n.ordersErrorNetwork;
  if (error is ValidationFailure) {
    for (final List<String> messages in error.fields.values) {
      if (messages.isNotEmpty && messages.first.trim().isNotEmpty) {
        return messages.first;
      }
    }
    if (error.message.trim().isNotEmpty) return error.message;
  }
  return l10n.ordersErrorGeneric;
}
