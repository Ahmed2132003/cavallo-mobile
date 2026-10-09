/// Part P-065 STEP 4 scope: [SearchFilterPanel] - the filter form shown
/// as a modal bottom sheet from `SearchScreen`. Presented via
/// `showModalBottomSheet<SearchFilters>`; pops the [SearchFilters] the
/// user built ("Apply"), a fresh `const SearchFilters()` ("Clear"), or
/// `null` if dismissed without either (swipe-down/tap-outside) - the
/// caller (`SearchScreen`) treats `null` as "keep whatever filters were
/// already active."
///
/// ### Why a bottom sheet, not an expandable section
///
/// A modal sheet keeps the results list's own scroll position and loaded
/// items completely untouched while filters are being edited, and gives the
/// filter form its own full-height space to lay out.
///
/// ### Category picker - the exact `product_form_screen.dart` (P-033)
/// pattern, duplicated, not imported
///
/// [_flattenCategories] is a private copy of that file's helper of the same
/// name, with one addition: an "All categories" entry mapping to `null`.
///
/// ### Part P-114 STEP 3B (presentation only)
///
/// Same fields, same keys, same result contract, same pops. Changed: every
/// string comes from the ARB files, padding is directional, the section
/// titles use the token text styles, the rating options are formatted by one
/// plural message, and Clear uses the outlined [AppButton] variant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../categories/domain/category_entity.dart';
import '../../categories/presentation/category_tree_provider.dart';
import '../domain/search_filters.dart';

class SearchFilterPanel extends ConsumerStatefulWidget {
  const SearchFilterPanel({super.key, required this.initialFilters});

  final SearchFilters initialFilters;

  @override
  ConsumerState<SearchFilterPanel> createState() => _SearchFilterPanelState();
}

class _SearchFilterPanelState extends ConsumerState<SearchFilterPanel> {
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  int? _categoryId;
  String? _businessType;
  String? _minRating;
  bool _featuredOnly = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    _countryController = TextEditingController(text: f.country ?? '');
    _cityController = TextEditingController(text: f.city ?? '');
    _categoryId = f.categoryId;
    _businessType = f.businessType;
    _minRating = f.minRating;
    _featuredOnly = f.featuredOnly;
  }

  @override
  void dispose() {
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  SearchFilters _buildFilters() {
    final country = _countryController.text.trim();
    final city = _cityController.text.trim();
    return SearchFilters(
      categoryId: _categoryId,
      country: country.isEmpty ? null : country,
      city: city.isEmpty ? null : city,
      businessType: _businessType,
      minRating: _minRating,
      featuredOnly: _featuredOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryTreeProvider);
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.appColors;
    final TextStyle? sectionStyle = theme.textTheme.labelLarge?.copyWith(
      color: colors.textSecondary,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.searchFilterTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildCategoryField(categoriesAsync),
              const SizedBox(height: 12),
              AppTextField(
                key: const Key('searchFilterPanel_countryField'),
                label: l10n.searchFilterCountry,
                controller: _countryController,
              ),
              const SizedBox(height: 12),
              AppTextField(
                key: const Key('searchFilterPanel_cityField'),
                label: l10n.searchFilterCity,
                controller: _cityController,
              ),
              const SizedBox(height: 16),
              Text(l10n.searchFilterBusinessType, style: sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text(l10n.searchFilterAny),
                    selected: _businessType == null,
                    onSelected: (_) => setState(() => _businessType = null),
                  ),
                  ChoiceChip(
                    label: Text(l10n.businessTypeTrader),
                    selected: _businessType == 'trader',
                    onSelected: (_) => setState(() => _businessType = 'trader'),
                  ),
                  ChoiceChip(
                    label: Text(l10n.businessTypeFactory),
                    selected: _businessType == 'factory',
                    onSelected:
                        (_) => setState(() => _businessType = 'factory'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.searchFilterMinRating, style: sectionStyle),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: const Key('searchFilterPanel_minRatingDropdown'),
                value: _minRating,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.searchFilterAny),
                  ),
                  for (final stars in const <int>[4, 3, 2, 1])
                    DropdownMenuItem(
                      value: '$stars',
                      child: Text(l10n.searchFilterMinRatingOption(stars)),
                    ),
                ],
                onChanged: (value) => setState(() => _minRating = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('searchFilterPanel_featuredSwitch'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.searchFilterFeaturedOnly),
                value: _featuredOnly,
                onChanged: (value) => setState(() => _featuredOnly = value),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.searchFilterClear,
                      variant: AppButtonVariant.outlined,
                      onPressed:
                          () =>
                              Navigator.of(context).pop(const SearchFilters()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: l10n.searchFilterApply,
                      onPressed:
                          () => Navigator.of(context).pop(_buildFilters()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryField(AsyncValue<List<CategoryNode>> categoriesAsync) {
    final l10n = context.l10n;
    return switch (categoriesAsync) {
      AsyncData(:final value) => DropdownButtonFormField<int?>(
        key: const Key('searchFilterPanel_categoryDropdown'),
        value: _categoryId,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.searchFilterCategory),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(l10n.searchFilterCategoryAll),
          ),
          for (final entry in _flattenCategories(value))
            DropdownMenuItem(
              value: entry.$1.id,
              child: Text(
                '${'\u2014' * entry.$2}${entry.$2 > 0 ? ' ' : ''}${entry.$1.name}',
              ),
            ),
        ],
        onChanged: (id) => setState(() => _categoryId = id),
      ),
      AsyncError() => Row(
        children: [
          Expanded(child: Text(l10n.searchFilterCategoriesFailed)),
          TextButton(
            onPressed: () => ref.invalidate(categoryTreeProvider),
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
    };
  }
}

/// See this file's module docstring - a deliberate, verbatim duplicate
/// of `product_form_screen.dart`'s own private `_flattenCategories`.
List<(CategoryNode, int)> _flattenCategories(
  List<CategoryNode> nodes, [
  int depth = 0,
]) {
  final result = <(CategoryNode, int)>[];
  for (final node in nodes) {
    result.add((node, depth));
    result.addAll(_flattenCategories(node.children, depth + 1));
  }
  return result;
}
