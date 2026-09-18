import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../categories/domain/category_entity.dart';
import '../../categories/presentation/category_tree_provider.dart';
import '../data/product_variant_repository_impl.dart';
import '../domain/product_entity.dart';
import '../domain/product_variant_entity.dart';
import 'own_products_provider.dart';

/// Part P-033 scope: `lib/features/products/presentation/
/// product_form_screen.dart` — the shared create/edit form
/// (`existingProduct == null` → create, non-null → edit), calling
/// `OwnProductsNotifier.createProduct`/`updateProduct` (STEP 7) for the
/// scalar fields + image (one multipart request, per
/// `ProductRepository`'s own docstring), then [_syncVariants] for the
/// variant add/remove/edit rows via `ProductVariantRepository`
/// (Part P-032B) — a separate write path that needs a real, already-
/// persisted `productId`.
///
/// See this part's own STEP 9 message for the three explicitly-flagged
/// scope decisions this file makes (shared create/edit, no
/// `RouteNames` dependency — plain `Navigator.pop` on success instead,
/// and variant sync happening strictly after the product itself is
/// saved).
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.existingProduct});

  /// `null` for create mode. Non-null for edit mode — every field below
  /// is pre-filled from it.
  final Product? existingProduct;

  bool get isEditing => existingProduct != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final List<_VariantRow> _variantRows;

  Currency? _currency;
  int? _categoryId;
  bool _isActive = true;
  File? _imageFile;

  bool _isSubmitting = false;

  /// Backend-driven, field-specific error text — set only from a
  /// [ValidationFailure]'s `fields` map (Part P-004), keyed by the
  /// exact field names `ProductRepositoryImpl` already sends
  /// (`name`, `description`, `price`, `currency`, `category`, `image`).
  String? _nameError;
  String? _descriptionError;
  String? _priceError;
  String? _currencyError;
  String? _categoryError;
  String? _imageError;

  /// Any failure that doesn't map onto a specific field above, or a
  /// local (non-backend) validation problem such as an incomplete
  /// variant row.
  String? _generalError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProduct;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _priceController = TextEditingController(text: existing?.price ?? '');
    _currency = existing?.currency;
    _categoryId = existing?.categoryId;
    _isActive = existing?.isActive ?? true;
    _variantRows = [
      for (final variant in existing?.variants ?? const <ProductVariant>[])
        _VariantRow(id: variant.id, name: variant.name, value: variant.value),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    for (final row in _variantRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  void _addVariantRow() {
    setState(() => _variantRows.add(_VariantRow()));
  }

  void _removeVariantRow(int index) {
    setState(() {
      _variantRows[index].dispose();
      _variantRows.removeAt(index);
    });
  }

  /// Reconciles [_variantRows] against `widget.existingProduct?.variants`
  /// (empty for create mode, so every row is a plain create there) via
  /// `ProductVariantRepository` (Part P-032B): rows whose original id is
  /// no longer present are deleted, rows with no id yet are created,
  /// and rows whose id is still present but whose text changed are
  /// updated. A row whose name/value didn't change from its original is
  /// left untouched — no pointless PATCH for it.
  Future<void> _syncVariants(int productId) async {
    final variantRepository = ref.read(productVariantRepositoryProvider);
    final originalVariants =
        widget.existingProduct?.variants ?? const <ProductVariant>[];
    final originalIds = originalVariants
        .map((v) => v.id)
        .whereType<int>()
        .toSet();
    final currentIds = _variantRows.map((r) => r.id).whereType<int>().toSet();

    for (final removedId in originalIds.difference(currentIds)) {
      await variantRepository.deleteVariant(
        productId: productId,
        variantId: removedId,
      );
    }

    for (final row in _variantRows) {
      final name = row.nameController.text.trim();
      final value = row.valueController.text.trim();

      if (row.id == null) {
        await variantRepository.createVariant(
          productId: productId,
          name: name,
          value: value,
        );
        continue;
      }

      ProductVariant? original;
      for (final variant in originalVariants) {
        if (variant.id == row.id) {
          original = variant;
          break;
        }
      }
      if (original != null &&
          (original.name != name || original.value != value)) {
        await variantRepository.updateVariant(
          productId: productId,
          variantId: row.id!,
          name: name,
          value: value,
        );
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _nameError = null;
      _descriptionError = null;
      _priceError = null;
      _currencyError = null;
      _categoryError = null;
      _imageError = null;
      _generalError = null;
    });

    // Drop rows the user opened via "Add variant" but left completely
    // untouched — a harmless leftover, not something to validate.
    _variantRows.removeWhere(
      (row) =>
          row.nameController.text.trim().isEmpty &&
          row.valueController.text.trim().isEmpty,
    );

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    for (final row in _variantRows) {
      final hasName = row.nameController.text.trim().isNotEmpty;
      final hasValue = row.valueController.text.trim().isNotEmpty;
      if (hasName != hasValue) {
        setState(
          () => _generalError =
              'Each variant needs both a name and a value, or remove it.',
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final price = _priceController.text.trim();

      final int productId;
      if (widget.isEditing) {
        final updated = await ref
            .read(ownProductsProvider.notifier)
            .updateProduct(
              productId: widget.existingProduct!.id,
              categoryId: _categoryId,
              name: name,
              description: description,
              price: price,
              currency: _currency,
              imageFile: _imageFile,
              isActive: _isActive,
            );
        productId = updated.id;
      } else {
        final created = await ref
            .read(ownProductsProvider.notifier)
            .createProduct(
              categoryId: _categoryId!,
              name: name,
              description: description,
              price: price,
              currency: _currency!,
              imageFile: _imageFile,
              isActive: _isActive,
            );
        productId = created.id;
      }

      await _syncVariants(productId);
      await ref.read(ownProductsProvider.notifier).refreshProducts();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      final failure = switch (error) {
        DioException(error: final ApiFailure f) => f,
        ApiFailure() => error,
        _ => null,
      };
      if (!mounted) return;
      setState(() {
        if (failure == null) {
          _generalError = 'Something went wrong. Please try again.';
          return;
        }
        switch (failure) {
          case ValidationFailure(:final fields):
            _nameError = fields['name']?.join(' ');
            _descriptionError = fields['description']?.join(' ');
            _priceError = fields['price']?.join(' ');
            _currencyError = fields['currency']?.join(' ');
            _categoryError = fields['category']?.join(' ');
            _imageError = fields['image']?.join(' ');
            if (_nameError == null &&
                _descriptionError == null &&
                _priceError == null &&
                _currencyError == null &&
                _categoryError == null &&
                _imageError == null) {
              _generalError = failure.message;
            }
          case AuthFailure() ||
              NetworkFailure() ||
              ServerFailure() ||
              UnknownFailure():
            _generalError = failure.message;
        }
      });
      _formKey.currentState?.validate();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildImagePicker(BuildContext context) {
    final previewUrl = widget.existingProduct?.imageUrl;
    final theme = Theme.of(context);
    const previewSize = 120.0;

    Widget preview;
    if (_imageFile != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _imageFile!,
          width: previewSize,
          height: previewSize,
          fit: BoxFit.cover,
        ),
      );
    } else if (previewUrl != null && previewUrl.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          previewUrl,
          width: previewSize,
          height: previewSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: previewSize,
            height: previewSize,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    } else {
      preview = Container(
        width: previewSize,
        height: previewSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add_a_photo_outlined),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product image (optional)'),
        const SizedBox(height: 8),
        preview,
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isSubmitting ? null : _pickImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(_imageFile == null ? 'Choose image' : 'Change image'),
        ),
        if (_imageError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _imageError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildVariantRow(int index, _VariantRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              key: Key('productForm_variantName_$index'),
              label: 'Variant name (e.g. Size)',
              controller: row.nameController,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              key: Key('productForm_variantValue_$index'),
              label: 'Value (e.g. Large)',
              controller: row.valueController,
            ),
          ),
          IconButton(
            key: Key('productForm_removeVariant_$index'),
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Remove variant',
            onPressed: _isSubmitting ? null : () => _removeVariantRow(index),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField(AsyncValue<List<CategoryNode>> categoriesAsync) {
    return switch (categoriesAsync) {
      AsyncData(:final value) => DropdownButtonFormField<int>(
        key: const Key('productForm_categoryDropdown'),
        value: _categoryId,
        decoration: const InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final entry in _flattenCategories(value))
            DropdownMenuItem(
              value: entry.$1.id,
              child: Text('${'—' * entry.$2}${entry.$2 > 0 ? ' ' : ''}${entry.$1.name}'),
            ),
        ],
        onChanged: (id) => setState(() => _categoryId = id),
        validator: (id) {
          if (_categoryError != null) return _categoryError;
          if (id == null) return 'Category is required.';
          return null;
        },
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryTreeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit product' : 'Create product'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const Key('productForm_nameField'),
                  label: 'Name',
                  controller: _nameController,
                  validator: (value) {
                    if (_nameError != null) return _nameError;
                    if ((value ?? '').trim().isEmpty) {
                      return 'Name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  key: const Key('productForm_descriptionField'),
                  label: 'Description',
                  controller: _descriptionController,
                  maxLines: 4,
                  validator: (value) {
                    if (_descriptionError != null) return _descriptionError;
                    if ((value ?? '').trim().isEmpty) {
                      return 'Description is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  key: const Key('productForm_priceField'),
                  label: 'Price',
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (_priceError != null) return _priceError;
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Price is required.';
                    if (double.tryParse(text) == null) {
                      return 'Enter a valid price (e.g. 199.99).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Currency>(
                  key: const Key('productForm_currencyDropdown'),
                  value: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final currency in Currency.values)
                      DropdownMenuItem(
                        value: currency,
                        child: Text(currency.toWire()),
                      ),
                  ],
                  onChanged: (currency) =>
                      setState(() => _currency = currency),
                  validator: (currency) {
                    if (_currencyError != null) return _currencyError;
                    if (currency == null) return 'Currency is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildCategoryField(categoriesAsync),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('productForm_activeSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active (visible to customers)'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 16),
                _buildImagePicker(context),
                const SizedBox(height: 24),
                Text('Variants', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < _variantRows.length; i++)
                  _buildVariantRow(i, _variantRows[i]),
                TextButton.icon(
                  key: const Key('productForm_addVariantButton'),
                  onPressed: _isSubmitting ? null : _addVariantRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add variant'),
                ),
                if (_generalError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _generalError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  key: const Key('productForm_submitButton'),
                  label: widget.isEditing ? 'Save changes' : 'Create product',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One locally-held variant row. `id == null` means "added in this
/// form session, not yet persisted" — see [_ProductFormScreenState._syncVariants].
class _VariantRow {
  _VariantRow({this.id, String name = '', String value = ''})
    : nameController = TextEditingController(text: name),
      valueController = TextEditingController(text: value);

  final int? id;
  final TextEditingController nameController;
  final TextEditingController valueController;

  void dispose() {
    nameController.dispose();
    valueController.dispose();
  }
}

/// Flattens the category tree into `(node, depth)` pairs, depth-first,
/// preserving the backend's own order at every level — the "simple
/// flattened dropdown with indentation" this part's own spec explicitly
/// allows as an MVP category picker.
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