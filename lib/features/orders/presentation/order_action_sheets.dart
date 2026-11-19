import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/order.dart';
import '../domain/order_status.dart';
import 'order_error_text.dart';
import 'order_status_chip.dart';
import 'orders_providers.dart';

/// Merchant: move [order] to one of its server-allowed next statuses, with an
/// optional customer-visible note. Returns `true` when the status changed.
Future<bool> showChangeStatusSheet(
  BuildContext context, {
  required Order order,
}) async {
  final bool? changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (BuildContext _) => _ChangeStatusSheet(order: order),
  );
  return changed ?? false;
}

/// Merchant: add a note (internal by default) to [order]. Returns `true` when
/// the note was saved.
Future<bool> showAddNoteSheet(
  BuildContext context, {
  required Order order,
}) async {
  final bool? added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (BuildContext _) => _AddNoteSheet(order: order),
  );
  return added ?? false;
}

class _ChangeStatusSheet extends ConsumerStatefulWidget {
  const _ChangeStatusSheet({required this.order});

  final Order order;

  @override
  ConsumerState<_ChangeStatusSheet> createState() => _ChangeStatusSheetState();
}

class _ChangeStatusSheetState extends ConsumerState<_ChangeStatusSheet> {
  final TextEditingController _note = TextEditingController();
  OrderStatus? _selected;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final OrderStatus? target = _selected;
    if (_submitting || target == null) return;
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final OrderActions actions = ref.read(orderActionsProvider);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await actions.changeStatus(
        orderId: widget.order.id,
        status: target,
        note: _note.text,
      );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.ordersStatusChanged)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = orderErrorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;
    final List<OrderStatus> options = widget.order.allowedNextStatuses;

    return PopScope(
      canPop: !_submitting,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.ordersChangeStatusTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (options.isEmpty)
                  Text(
                    l10n.ordersStatusNoTransitions,
                    style: TextStyle(color: colors.textSecondary),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final OrderStatus status in options)
                        ChoiceChip(
                          key: ValueKey<String>('statusOption_${status.name}'),
                          label: Text(orderStatusLabel(l10n, status)),
                          selected: _selected == status,
                          onSelected:
                              _submitting
                                  ? null
                                  : (bool on) => setState(
                                    () => _selected = on ? status : null,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>('statusNoteField'),
                    controller: _note,
                    enabled: !_submitting,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.ordersStatusNoteHint,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: colors.dangerText)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                        child: Text(l10n.ordersActionCancel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey<String>('statusSaveButton'),
                        onPressed:
                            (_submitting || _selected == null) ? null : _submit,
                        child: Text(l10n.ordersActionSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({required this.order});

  final Order order;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final TextEditingController _note = TextEditingController();

  // Internal by default: the safe choice, the merchant must opt in to showing
  // a note to the customer.
  bool _internal = true;
  bool _submitting = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_note.text.trim().isEmpty) {
      setState(() => _attempted = true);
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final OrderActions actions = ref.read(orderActionsProvider);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await actions.addNote(
        orderId: widget.order.id,
        note: _note.text,
        isInternal: _internal,
      );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.ordersNoteAdded)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = orderErrorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppColors colors = context.appColors;

    return PopScope(
      canPop: !_submitting,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.ordersAddNote,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('noteField'),
                  controller: _note,
                  enabled: !_submitting,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.ordersNoteHint,
                    errorText:
                        (_attempted && _note.text.trim().isEmpty)
                            ? l10n.ordersNoteRequired
                            : null,
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey<String>('noteInternalSwitch'),
                  contentPadding: EdgeInsets.zero,
                  value: _internal,
                  onChanged:
                      _submitting
                          ? null
                          : (bool value) => setState(() => _internal = value),
                  title: Text(l10n.ordersNoteInternalToggle),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: TextStyle(color: colors.dangerText)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                        child: Text(l10n.ordersActionCancel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey<String>('noteSaveButton'),
                        onPressed: _submitting ? null : _submit,
                        child: Text(l10n.ordersActionSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
