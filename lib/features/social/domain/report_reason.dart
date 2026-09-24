/// Part P-058 scope: the fixed 4-reason enum `reports/targets.py` and
/// `Report.Reason` (backend, Part P-057) accept — confirmed against
/// the real backend source. The Flutter Report dialog (a later step)
/// must offer EXACTLY these 4 and nothing else; do not add a 5th
/// option locally.
enum ReportReason {
  spam,
  inappropriate,
  misleading,
  other;

  /// The exact lowercase string the backend expects in the `reason`
  /// field of `POST /api/v1/reports/`.
  String get wireValue => switch (this) {
    ReportReason.spam => 'spam',
    ReportReason.inappropriate => 'inappropriate',
    ReportReason.misleading => 'misleading',
    ReportReason.other => 'other',
  };
}

/// Part P-058 scope: `reports/targets.py`'s own closed whitelist
/// (`REPORT_ALLOWED_CONTENT_TYPES`) — separate from Like's/Save's/
/// Comment's/Share's, per that app's own documented convention.
/// `"user"` is deliberately NOT included (P-057's own "Remaining
/// work" flags reporting a User as an open product gap, not built).
const List<String> reportAllowedContentTypes = [
  'comment',
  'post',
  'reel',
  'story',
  'product',
  'business',
];