/// Part BI-04: manual entry / update of one external number.
///
/// POST business/{id}/content/{type}/{id}/external-metrics/ with
/// {platform, metric_type, metric_value (int >= 0), external_reference?}.
/// `source` is never sent (the backend always stores "manual"). `captured_at`
/// is not sent either: it may not be in the future and a device clock that is
/// ahead of the server would turn a valid entry into a 400.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/l10n_context.dart';
import '../../../../business_profile/presentation/business_profile_provider.dart';
import '../../../data/business_analytics_repository.dart';
import '../../../domain/analytics_content.dart';
import '../../analytics_provider.dart'
    show AnalyticsBusinessUnavailableException;
import 'external_metrics_panel.dart';

/// Resolves to true when a number was saved.
Future<bool?> showExternalMetricSheet(
  BuildContext context, {
  required String contentType,
  required int contentId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (BuildContext context) => ExternalMetricFormSheet(
          contentType: contentType,
          contentId: contentId,
        ),
  );
}

class ExternalMetricFormSheet extends ConsumerStatefulWidget {
  const ExternalMetricFormSheet({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  final String contentType;
  final int contentId;

  @override
  ConsumerState<ExternalMetricFormSheet> createState() =>
      _ExternalMetricFormSheetState();
}

class _ExternalMetricFormSheetState
    extends ConsumerState<ExternalMetricFormSheet> {
  static const List<String> platforms = <String>[
    'instagram',
    'facebook',
    'tiktok',
  ];
  static const List<String> metricTypes = <String>[
    'views',
    'likes',
    'shares',
    'saves',
  ];

  final TextEditingController _value = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  String _platform = platforms.first;
  String _metricType = metricTypes.first;
  bool _busy = false;
  bool _valueInvalid = false;
  bool _saveFailed = false;

  @override
  void dispose() {
    _value.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String raw = _value.text.trim();
    final int? parsed = raw.length > 12 ? null : int.tryParse(raw);
    if (parsed == null || parsed < 0) {
      setState(() => _valueInvalid = true);
      return;
    }
    setState(() {
      _busy = true;
      _valueInvalid = false;
      _saveFailed = false;
    });
    try {
      final profile = await ref.read(businessProfileProvider.future);
      if (profile == null) {
        throw const AnalyticsBusinessUnavailableException();
      }
      final String reference = _reference.text.trim();
      await ref
          .read(businessAnalyticsRepositoryProvider)
          .submitExternalMetric(
            businessId: profile.id,
            contentType: widget.contentType,
            contentId: widget.contentId,
            input: ExternalMetricInput(
              platform: _platform,
              metricType: _metricType,
              metricValue: parsed,
              externalReference: reference.isEmpty ? null : reference,
            ),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.analyticsExternalFormTitle, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.analyticsExternalFormNote, style: text.bodySmall),
            const SizedBox(height: 16),
            Text(l10n.analyticsExternalFormPlatform, style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final String p in platforms)
                  ChoiceChip(
                    key: Key('analytics-external-form-platform-$p'),
                    label: Text(externalPlatformLabel(l10n, p)),
                    selected: p == _platform,
                    onSelected:
                        _busy
                            ? null
                            : (bool _) => setState(() => _platform = p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.analyticsExternalFormMetric, style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final String m in metricTypes)
                  ChoiceChip(
                    key: Key('analytics-external-form-metric-$m'),
                    label: Text(externalMetricLabel(l10n, m)),
                    selected: m == _metricType,
                    onSelected:
                        _busy
                            ? null
                            : (bool _) => setState(() => _metricType = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('analytics-external-form-value'),
              controller: _value,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: l10n.analyticsExternalFormValue,
                errorText:
                    _valueInvalid ? l10n.analyticsExternalValueInvalid : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('analytics-external-form-reference'),
              controller: _reference,
              enabled: !_busy,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.analyticsExternalFormReference,
              ),
            ),
            if (_saveFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.analyticsExternalSaveError,
                  key: const Key('analytics-external-form-error'),
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('analytics-external-form-submit'),
                onPressed: _busy ? null : _submit,
                child:
                    _busy
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(l10n.analyticsExternalFormSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
