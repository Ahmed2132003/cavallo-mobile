/// Part P-065 STEP 4 scope: [SearchFilterPanel] — the filter form shown
/// as a modal bottom sheet from `SearchScreen`. Presented via
/// `showModalBottomSheet<SearchFilters>`; pops the [SearchFilters] the
/// user built ("Apply"), a fresh `const SearchFilters()` ("Clear"), or
/// `null` if dismissed without either (swipe-down/tap-outside) — the
/// caller (`SearchScreen`) treats `null` as "keep whatever filters were
/// already active."
///
/// ### Why a bottom sheet, not an expandable section
///
/// No filter-panel precedent already exists elsewhere in this project
/// to follow, so this is a new, flagged decision: a modal sheet keeps
/// the results list's own scroll position and loaded items completely
/// untouched while filters are being edited, and gives the filter form
/// its own full-height space to lay out — an inline expandable section
/// would either cramp the fields or need to shrink the results list
/// underneath it.
///
/// ### Category picker — the exact `product_form_screen.dart` (P-033)
/// pattern, duplicated, not imported
///
/// No shared `CategoryPicker` widget exists yet — `product_form_screen.
/// dart`'s own "simple flattened dropdown with indentation" is the only
/// precedent. [_flattenCategories] here is a private, verbatim copy of
/// that file's own private helper of the same name (harmless — each is
/// private to its own library), with one addition: an "All categories"
/// entry mapping to `null`, since a category filter (unlike the product
/// form's required field) must support "no category filter applied."
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildCategoryField(categoriesAsync),
              const SizedBox(height: 12),
              AppTextField(
                key: const Key('searchFilterPanel_countryField'),
                label: 'Country',
                controller: _countryController,
              ),
              const SizedBox(height: 12),
              AppTextField(
                key: const Key('searchFilterPanel_cityField'),
                label: 'City',
                controller: _cityController,
              ),
              const SizedBox(height: 16),
              Text(
                'Business type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Any'),
                    selected: _businessType == null,
                    onSelected: (_) => setState(() => _businessType = null),
                  ),
                  ChoiceChip(
                    label: const Text('Trader'),
                    selected: _businessType == 'trader',
                    onSelected: (_) =>
                        setState(() => _businessType = 'trader'),
                  ),
                  ChoiceChip(
                    label: const Text('Factory'),
                    selected: _businessType == 'factory',
                    onSelected: (_) =>
                        setState(() => _businessType = 'factory'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Minimum rating',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: const Key('searchFilterPanel_minRatingDropdown'),
                value: _minRating,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: '4', child: Text('4 stars & up')),
                  DropdownMenuItem(value: '3', child: Text('3 stars & up')),
                  DropdownMenuItem(value: '2', child: Text('2 stars & up')),
                  DropdownMenuItem(value: '1', child: Text('1 star & up')),
                ],
                onChanged: (value) => setState(() => _minRating = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('searchFilterPanel_featuredSwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured only'),
                value: _featuredOnly,
                onChanged: (value) => setState(() => _featuredOnly = value),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const SearchFilters()),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Apply',
                      onPressed: () =>
                          Navigator.of(context).pop(_buildFilters()),
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
    return switch (categoriesAsync) {
      AsyncData(:final value) => DropdownButtonFormField<int?>(
        key: const Key('searchFilterPanel_categoryDropdown'),
        value: _categoryId,
        decoration: const InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All categories')),
          for (final entry in _flattenCategories(value))
            DropdownMenuItem(
              value: entry.$1.id,
              child: Text(
                '${'—' * entry.$2}${entry.$2 > 0 ? ' ' : ''}${entry.$1.name}',
              ),
            ),
        ],
        onChanged: (id) => setState(() => _categoryId = id),
      ),
      AsyncError() => Row(
        children: [
          const Expanded(child: Text('Could not load categories.')),
          TextButton(
            onPressed: () => ref.invalidate(categoryTreeProvider),
            child: const Text('Retry'),
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

/// See this file's module docstring — a deliberate, verbatim duplicate
/// of `product_form_screen.dart`'s own private `_flattenCategories`,
/// plus this filter's own "All categories" entry handled separately
/// above (not inside this helper, which only ever flattens real nodes).
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