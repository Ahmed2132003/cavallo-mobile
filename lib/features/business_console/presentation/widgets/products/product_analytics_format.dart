/// Part BI-04: value formatting shared by the Products widgets. A missing
/// value (null from the API) is always "—", never 0.
library;

import '../../../../../core/l10n/formatters.dart';
import '../../../../../l10n/app_localizations.dart';

const String kProductMissing = '—';

String productCountText(AppFormatters formatters, int? value) {
  if (value == null) {
    return kProductMissing;
  }
  return formatters.compactCount(value);
}

/// [value] is a fraction (0.1523 = 15.2%), exactly as the backend sends it.
String productRateText(AppLocalizations l10n, double? value) {
  if (value == null) {
    return kProductMissing;
  }
  return l10n.analyticsProdRateValue((value * 100).toStringAsFixed(1));
}
