/// Part BI-04: wrap a PRODUCT or POST detail screen's body with this widget to
/// record exactly one view when that screen opens.
///
/// Reels are not handled here because they need the watch time: the reel
/// player calls `ref.read(viewEventTrackerProvider).recordReelWatch(...)` once
/// the position first reaches 3000 ms.
///
/// Give the scope a key that contains the id, so opening another item builds a
/// new scope (and records its own view):
///
///     ViewTrackingScope(
///       key: ValueKey('view-product-$id'),
///       targetType: ViewTargetType.product,
///       targetId: id,
///       child: ...,
///     )
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/view_event_tracker.dart';

class ViewTrackingScope extends ConsumerStatefulWidget {
  const ViewTrackingScope({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.child,
  }) : assert(
         targetType != ViewTargetType.reel,
         'Reels are recorded by the player once watch_ms >= 3000.',
       );

  final ViewTargetType targetType;
  final int targetId;
  final Widget child;

  @override
  ConsumerState<ViewTrackingScope> createState() => _ViewTrackingScopeState();
}

class _ViewTrackingScopeState extends ConsumerState<ViewTrackingScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(viewEventTrackerProvider)
            .record(type: widget.targetType, targetId: widget.targetId),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
