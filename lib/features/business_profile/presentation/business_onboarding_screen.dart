import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../routing/route_names.dart';
import '../domain/business_profile_entity.dart';
import 'business_profile_provider.dart';

/// Part P-028B scope: `lib/features/business_profile/presentation/
/// business_onboarding_screen.dart` — the "complete your business
/// profile" form a newly registered Business user fills in once, calling
/// `BusinessProfileNotifier.createProfile` (this part's own addition to
/// `business_profile_provider.dart`) on submit.
///
/// ### Scope decisions — flagged explicitly, not silently made
///
/// 1. **No category picker.** The part spec's own "Detailed
///    Implementation"/"Out of Scope" notes are self-referential on this
///    point (confirm via P-026 whether a category FK exists; if so,
///    "this part must include a category picker"). P-026 *did* add a
///    nullable `category` FK (confirmed in `business_profile_entity.dart`
///    /`business_profile_repository.dart`, Part P-028A) — but Part
///    P-028A's own handoff note already assigned the actual
///    category-tree-based *picker widget* to whichever part builds it,
///    flagging that **no Flutter `categories` feature/provider exists
///    anywhere in this app yet** (no `GET /api/v1/categories/tree/`
///    consumer, no cache-key convention chosen). Building an entire new
///    feature (tree fetch + cache + picker UI) is a materially larger
///    scope than this part's own literal "Files Expected" list (just
///    this screen + `pubspec.yaml`). Since `BusinessProfile.category` is
///    optional — a Business can complete onboarding without picking one
///    (P-026's own "Gap check for later phases" note) — this screen
///    omits the picker entirely (`categoryId: null` on submit) rather
///    than block onboarding on it. **This is a real open item for
///    whoever builds the Flutter `categories` feature, not a silent
///    decision** — the edit screen (Part P-028C) inherits the same open
///    item.
/// 2. **`country`/`city` are free-text [AppTextField]s**, per the part
///    spec's own explicitly-allowed MVP fallback ("a free-text fallback
///    is acceptable for MVP, document the choice").
/// 3. **`business_type` uses a [SegmentedButton]**, not a
///    `DropdownButtonFormField` — deliberately mirroring
///    `RegisterScreen`'s existing `SegmentedButton<AccountType>` picker
///    (Part P-021c) exactly, for one consistent "pick one of two things"
///    pattern across the app, rather than introducing a second UI
///    idiom for the same kind of choice. Satisfies the part spec's own
///    "a simple radio/dropdown" framing either way.
/// 4. **International phone input uses the `intl_phone_field` package**
///    (v3.2.0 at authoring time), per the part spec's own suggestion.
///    ⚠️ Flagged: this package's last real release was published in
///    2023 and it does not appear to be under active development
///    (confirmed by checking pub.dev directly, not assumed) — it is
///    NOT marked discontinued on pub.dev, and its source has no
///    dependencies beyond the Flutter SDK itself (confirmed by reading
///    its `pubspec.yaml` directly), so it's a reasonably low-risk pull
///    into this project even so. `flutter pub get`/`flutter analyze`
///    still need to confirm it resolves cleanly against this project's
///    pinned `flutter_riverpod: 3.3.2`/Flutter `>=3.27.0` floor on the
///    real machine — not yet run here (no Flutter SDK/pub.dev access in
///    this authoring environment, the same documented gap every
///    sandbox-authored part in this project has hit). If it turns out
///    to be a real problem on the real machine, `intl_phone_field_v2`
///    (an actively-maintained fork with the same widget API) is a
///    drop-in alternative — swap the import and the pubspec entry only.
///    Confirmed directly from the package's own source
///    (`lib/intl_phone_field.dart`/`lib/phone_number.dart`, not
///    assumed): `PhoneNumber.completeNumber` is built as
///    `'+${selectedCountry.dialCode}${selectedCountry.regionCode}' +
///    number` — i.e. always a leading `+` followed by digits only, no
///    spaces — which is exactly the E.164-formattable shape Part P-027's
///    backend validation (`phonenumbers.parse(value, None)`, no default
///    region) requires. `initialCountryCode: 'EG'` is a placeholder
///    default (this app's primary market at authoring time), not a
///    hardcoded assumption — the picker lets the user change it, and
///    nothing downstream depends on `'EG'` specifically.
/// 5. **The phone field is optional**, per the real backend contract
///    (`BusinessProfile.phone_number` — `CharField(blank=True,
///    default="")`, Part P-027): leaving it untouched submits `null`
///    (omitted from the request body — see
///    `BusinessProfileRepositoryImpl.createProfile`, Part P-028A) rather
///    than blocking submission. Confirmed directly from
///    `intl_phone_field`'s own source (`helpers.dart`'s `isNumeric`):
///    its built-in per-country length validator only engages once the
///    field is non-empty, so an untouched field passes `Form.validate()`
///    on its own — no extra "skip validation if empty" logic was needed
///    here.
/// 6. **`description` needs a multiline [AppTextField]** — Part P-006's
///    original widget had no `maxLines` parameter (single-line only).
///    Added one, backward-compatible, directly to
///    `lib/core/widgets/app_text_field.dart` (see that file's own
///    docstring) rather than reaching for a raw multiline
///    `TextFormField` here, which would itself have been the kind of
///    "every form uses `AppTextField`" deviation this project's
///    convention flags.
/// 7. **Manual navigation to `/home` on success** — unlike
///    `LoginScreen`/`RegisterScreen` (Part P-021b/c), which rely on the
///    router's own redirect guard reacting to `sessionProvider`. No such
///    guard exists yet for `businessProfileProvider` — wiring one is
///    explicitly Part P-028C's job (per this part's own EXECUTION
///    PROMPT: "Submitting calls businessProfileProvider's create method
///    (POST), and on success navigates to /home"), so this screen
///    navigates manually via `context.goNamed(RouteNames.home)` instead
///    of waiting on a guard that isn't built yet. Part P-028C's router
///    change should not need to touch this file — once its guard exists,
///    this manual navigation call simply becomes redundant with (not in
///    conflict with) the guard's own redirect, exactly like
///    `RegisterScreen`'s explicit `context.goNamed(RouteNames.login)`
///    call on its own non-happy path coexists with the router's guard on
///    the happy path.
class BusinessOnboardingScreen extends ConsumerStatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  ConsumerState<BusinessOnboardingScreen> createState() =>
      _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState
    extends ConsumerState<BusinessOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  BusinessType _businessType = BusinessType.trader;

  /// E.164-formatted (e.g. `"+201001234567"`) once the phone field has a
  /// non-empty value, `null` while it's left untouched — see this
  /// class's docstring, point 5. Updated from [IntlPhoneField.onChanged]
  /// on every keystroke, not just on submit, so a mid-typing malformed
  /// value doesn't linger past a fix.
  String? _phoneNumber;

  bool _isSubmitting = false;

  /// Backend-driven, field-specific error text — set only from a
  /// [ValidationFailure]'s `fields` map (Part P-004), keyed by the
  /// confirmed real backend field names (`business_name`,
  /// `business_type`, `country`, `city`, `description`, `phone_number` —
  /// Parts P-026/P-027). `business_type`/`phone_number` have no
  /// [Form]-integrated validator of their own ([SegmentedButton]/
  /// [IntlPhoneField] don't plug into this screen's [_formKey] the same
  /// way an [AppTextField] does) so their backend errors are rendered as
  /// a plain [Text] beneath each control instead, mirroring exactly how
  /// `RegisterScreen` shows `_accountTypeFieldError` beneath its own
  /// `SegmentedButton` (Part P-021c).
  String? _businessNameError;
  String? _businessTypeError;
  String? _countryError;
  String? _cityError;
  String? _descriptionError;
  String? _phoneNumberError;

  /// Any failure that doesn't map onto a specific field above.
  String? _generalError;

  @override
  void dispose() {
    _businessNameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear any previous backend-driven errors before re-validating, so
    // a field the user has since fixed doesn't keep showing a stale
    // server-side complaint from an earlier attempt — mirrors
    // LoginScreen/RegisterScreen's exact convention.
    setState(() {
      _businessNameError = null;
      _businessTypeError = null;
      _countryError = null;
      _cityError = null;
      _descriptionError = null;
      _phoneNumberError = null;
      _generalError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    final trimmedDescription = _descriptionController.text.trim();

    try {
      await ref
          .read(businessProfileProvider.notifier)
          .createProfile(
            businessName: _businessNameController.text.trim(),
            businessType: _businessType,
            country: _countryController.text.trim(),
            city: _cityController.text.trim(),
            description: trimmedDescription.isEmpty
                ? null
                : trimmedDescription,
            phoneNumber: _phoneNumber,
          );
      if (!mounted) return;
      context.goNamed(RouteNames.home);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        switch (failure) {
          case ValidationFailure(:final fields):
            _businessNameError = fields['business_name']?.join(' ');
            _businessTypeError = fields['business_type']?.join(' ');
            _countryError = fields['country']?.join(' ');
            _cityError = fields['city']?.join(' ');
            _descriptionError = fields['description']?.join(' ');
            _phoneNumberError = fields['phone_number']?.join(' ');
            if (_businessNameError == null &&
                _businessTypeError == null &&
                _countryError == null &&
                _cityError == null &&
                _descriptionError == null &&
                _phoneNumberError == null) {
              _generalError = failure.message;
            }
          case AuthFailure() ||
              NetworkFailure() ||
              ServerFailure() ||
              UnknownFailure():
            _generalError = failure.message;
        }
      });
      // Validators only run when Form.validate() is called — re-run it
      // now so the field-error strings just set above actually render
      // for the AppTextField-backed fields (business_name/country/city/
      // description). business_type/phone_number aren't Form-validated
      // fields (see this class's field docstring above) — their Text
      // widgets already reflect the state set above without needing
      // this call.
      _formKey.currentState?.validate();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your business profile')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Business name',
                    controller: _businessNameController,
                    validator: (value) {
                      if (_businessNameError != null) {
                        return _businessNameError;
                      }
                      if ((value ?? '').trim().isEmpty) {
                        return 'Business name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Business type'),
                  const SizedBox(height: 8),
                  SegmentedButton<BusinessType>(
                    segments: const [
                      ButtonSegment(
                        value: BusinessType.trader,
                        label: Text('Trader'),
                      ),
                      ButtonSegment(
                        value: BusinessType.factory,
                        label: Text('Factory'),
                      ),
                    ],
                    selected: {_businessType},
                    onSelectionChanged: (selection) {
                      setState(() => _businessType = selection.first);
                    },
                  ),
                  if (_businessTypeError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _businessTypeError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Country',
                    controller: _countryController,
                    validator: (value) {
                      if (_countryError != null) return _countryError;
                      if ((value ?? '').trim().isEmpty) {
                        return 'Country is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'City',
                    controller: _cityController,
                    validator: (value) {
                      if (_cityError != null) return _cityError;
                      if ((value ?? '').trim().isEmpty) {
                        return 'City is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  IntlPhoneField(
                    decoration: const InputDecoration(
                      labelText: 'Phone number (optional)',
                      border: OutlineInputBorder(),
                    ),
                    initialCountryCode: 'EG',
                    invalidNumberMessage:
                        'Enter a valid phone number for the selected '
                        'country.',
                    onChanged: (phone) {
                      _phoneNumber = phone.number.isEmpty
                          ? null
                          : phone.completeNumber;
                    },
                  ),
                  if (_phoneNumberError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _phoneNumberError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Description (optional)',
                    controller: _descriptionController,
                    maxLines: 4,
                    validator: (_) => _descriptionError,
                  ),
                  if (_generalError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _generalError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Complete profile',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}