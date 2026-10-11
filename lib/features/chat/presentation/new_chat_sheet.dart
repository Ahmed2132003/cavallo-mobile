import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../data/conversation_repository.dart';
import '../domain/followed_business.dart';

/// "New chat" picker — a bottom sheet listing the businesses the current
/// user follows (`GET /api/v1/conversations/following/`). Resolves to the
/// picked [FollowedBusiness], or `null` if the sheet is dismissed.
///
/// The sheet only PICKS; the caller (`ChatListScreen`) starts the
/// conversation and navigates, so the busy state lives on the screen.
Future<FollowedBusiness?> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet<FollowedBusiness>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const NewChatSheet(),
  );
}

class NewChatSheet extends ConsumerStatefulWidget {
  const NewChatSheet({super.key});

  @override
  ConsumerState<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<NewChatSheet> {
  final _scrollController = ScrollController();

  List<FollowedBusiness> _businesses = [];
  String? _nextCursor;
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  ApiFailure? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || _nextCursor == null) return;
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoadingFirstPage = true;
      _error = null;
    });
    try {
      final page =
          await ref.read(conversationRepositoryProvider).listFollowedBusinesses();
      if (!mounted) return;
      setState(() {
        _businesses = page.results;
        _nextCursor = page.next;
        _isLoadingFirstPage = false;
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoadingFirstPage = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    final cursor = _nextCursor;
    if (cursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(conversationRepositoryProvider)
          .listFollowedBusinesses(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _businesses = [..._businesses, ...page.results];
        _nextCursor = page.next;
        _isLoadingMore = false;
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedApiError(context.l10n, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;
    final double maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.newChatSheetTitle,
                    style: text.titleLarge?.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.newChatSheetSubtitle,
                    style: text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: colors.outline),
            Flexible(child: _buildBody(l10n, colors, text)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, AppColors colors, TextTheme text) {
    if (_isLoadingFirstPage) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _businesses.isEmpty) {
      return ErrorStateWidget(
        message: localizedApiError(l10n, _error),
        onRetry: _loadFirstPage,
      );
    }
    if (_businesses.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.storefront_outlined,
        message: l10n.newChatSheetEmpty,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      itemCount: _businesses.length + (_nextCursor != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _businesses.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final FollowedBusiness business = _businesses[index];
        final String subtitle = _subtitle(l10n, business);
        return ListTile(
          key: ValueKey('newChat_${business.businessId}'),
          leading: AppAvatar(name: business.businessName, size: 44),
          title: Text(
            business.businessName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(color: colors.textPrimary),
          ),
          subtitle:
              subtitle.isEmpty
                  ? null
                  : Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
          onTap: () => Navigator.of(context).pop(business),
        );
      },
    );
  }
}

/// "Trader · Cairo, Egypt" — the type label is localized, and any part the
/// backend left empty is simply skipped.
String _subtitle(AppLocalizations l10n, FollowedBusiness business) {
  final String type = switch (business.businessType) {
    'trader' => l10n.businessTypeTrader,
    'factory' => l10n.businessTypeFactory,
    _ => '',
  };
  final String place = <String>[
    business.city,
    business.country,
  ].where((String p) => p.isNotEmpty).join(', ');
  return <String>[type, place].where((String p) => p.isNotEmpty).join(' · ');
}
