import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/business_profile_entity.dart';
import '../domain/business_profile_repository.dart';
import 'business_profile_provider.dart';

/// Part P-028C2 scope: `lib/features/business_profile/presentation/
/// business_profile_edit_screen.dart` — the authenticated Business
/// user's own profile view/edit screen, closing the lifecycle opened by
/// registration (P-021c), onboarding (P-028B) and the router gate
/// (P-028C1).
///
/// Loads the current profile from [businessProfileProvider], pre-fills
/// every editable field from it, and submits changes through
/// `BusinessProfileNotifier.updateProfile` (this part's own addition to
/// `business_profile_provider.dart`) → `PATCH /api/v1/businesses/me/`
/// (Part P-026).
///
/// This screen is **only** for the signed-in Business user's own
/// profile. The public, customer-facing "view business by id" screen is
/// Part P-029's (`RouteNames.businessProfile`, `/business/:id`) and
/// nothing here presents, links to, or duplicates it.
///
/// ### Scope decisions — flagged explicitly, not silently made
///
/// 1. **Still no category picker.** P-026 *did* add the nullable
///    `category` FK (confirmed again for this part against
///    `PROJECT_PROGRESS.md`'s own P-025/P-026 entries, not carried over
///    on trust), and this part's spec says the edit form must include a
///    picker if it exists. It is still **not** built here, for the same
///    reason P-028A, P-028B and P-028C1 each flagged in turn: there is
///    no Flutter `categories` feature anywhere in this app — no
///    `GET /api/v1/categories/tree/` consumer, no confirmed wire shape
///    for that endpoint's response, and P-028A's own still-open item
///    ("confirm the `category` field's real wire representation ... bare
///    int vs. nested object") was never closed. Building a picker on an
///    unconfirmed JSON shape is exactly what this part's own BEFORE
///    CODING step forbids ("do not guess field names").
///    **Consequence, and why this is safe rather than lossy:**
///    `categoryId` is submitted as `Patchable.unset()` — omitted from
///    the PATCH body entirely — so whatever category the profile
///    already has server-side is left untouched by every edit made from
///    this screen. It is never cleared as a side effect of editing
///    something else. This stays the single open item for whoever
///    builds the `categories` feature.
/// 2. **Only genuinely changed fields are sent.** Each field is
///    compared against the profile that seeded the form; unchanged ones
///    are omitted from the PATCH body (`null` for the non-nullable
///    fields, [Patchable.unset] for the nullable ones). A PATCH is a
///    partial update by definition, and sending every field on every
///    save would make "the user only edited the city" indistinguishable
///    from "the user re-asserted all seven fields" in the backend's
///    logs/validation. Submitting with nothing changed shows a
///    "no changes" message and makes no request at all.
/// 3. **Clearing a field is distinct from leaving it alone.** Emptying
///    the description (or deleting the phone number) sends
///    [Patchable.clear] — an explicit `null` — which is exactly the
///    case `BusinessProfileRepository.updateProfile`'s `Patchable`
///    tri-state exists for (Part P-028A). A plain nullable parameter
///    could not express it.
/// 4. **The form is re-seeded from the backend's own response after a
///    successful save** (via the `ValueKey(profile)` on
///    [_BusinessProfileEditForm] below): the server normalizes on write
///    — most visibly `phone_number` → E.164 (Part P-027) — so the
///    fields end up showing what a fresh `GET` would return, not what
///    the user typed. This is also what makes the acceptance criterion
///    "returning to the edit screen confirms the change persisted"
///    observable without leaving the screen.
/// 5. **The loading/error/empty states are resolved on `hasValue`-style
///    pattern matching of the *seeded* profile, not by re-matching the
///    provider on every rebuild.** `updateProfile` sets `state` to
///    `AsyncValue.loading()` synchronously while a save is in flight —
///    if this screen swapped to a spinner on every `AsyncLoading`, it
///    would unmount its own form (and its controllers, and the
///    in-flight `_submit`'s `context`) mid-save, and a
///    `ValidationFailure` coming back would have no form left to render
///    itself on. Once a profile has been seeded, the form stays
///    mounted; the save's own progress is shown by [AppButton]'s
///    `isLoading` instead.
/// 6. **No navigation on success.** Unlike the onboarding screen, which
///    must move the user on to `/home`, staying here is the point: the
///    user sees the saved values re-render from the server response.
class BusinessProfileEditScreen extends ConsumerStatefulWidget {
  const BusinessProfileEditScreen({super.key});

  @override
  ConsumerState<BusinessProfileEditScreen> createState() =>
      _BusinessProfileEditScreenState();
}

class _BusinessProfileEditScreenState
    extends ConsumerState<BusinessProfileEditScreen> {
  /// The last profile actually seen from the backend. Kept so the form
  /// survives the transient `AsyncLoading` a save produces — see this
  /// screen's docstring, point 5.
  BusinessProfile? _seed;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessProfileProvider);

    // Pattern-matched rather than `.value`/`.valueOrNull` — neither is
    // used anywhere in this project, and `valueOrNull` specifically is
    // not exposed on this project's pinned `flutter_riverpod` version
    // (3.3.2; confirmed on the real machine in Part P-028B, and relied
    // on again by `app_router.dart`'s own redirect, Part P-021b/C1).
    if (state case AsyncData(value: final BusinessProfile profile)) {
      // Assigned during build on purpose, without setState: it is
      // derived from the very value this build is already rendering
      // with, so it can't desynchronise the frame.
      _seed = profile;
    }

    final seed = _seed;

    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: SafeArea(
        child: switch ((seed, state)) {
          (final BusinessProfile profile, _) => _BusinessProfileEditForm(
            // Re-seeds the whole form (controllers included) whenever
            // the backend hands back a different profile — see this
            // screen's docstring, point 4. `BusinessProfile` implements
            // `==`/`hashCode` over every field (Part P-028A), so an
            // unchanged profile keeps the exact same key and the form's
            // own state is preserved across unrelated rebuilds.
            key: ValueKey<BusinessProfile>(profile),
            profile: profile,
          ),
          (null, AsyncError(:final error)) => _ErrorView(error: error),
          // A genuine, confirmed "no profile yet" (a 404 mapped to null
          // by `BusinessProfileRepositoryImpl.fetchMyProfile`). Part
          // P-028C1's router gate should already have redirected this
          // user to onboarding before they could reach this route at
          // all, so this branch is a defensive fallback, not a normal
          // path — it deliberately does not navigate anywhere itself,
          // which would mean two different places in the app racing to
          // decide where a profile-less Business user belongs.
          (null, AsyncData(value: null)) => const _NoProfileView(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Shown only before any profile has ever loaded — see
/// [_BusinessProfileEditScreenState.build]'s own comments for why a
/// failure *after* that point is handled inline by the form instead.
class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (error) {
      ApiFailure(:final message) => message,
      _ => 'Could not load your business profile.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Retry',
              onPressed: () =>
                  ref.read(businessProfileProvider.notifier).refreshProfile(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoProfileView extends StatelessWidget {
  const _NoProfileView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'You have not completed your business profile yet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// The form itself, seeded once from [profile] in [initState] — see
/// [BusinessProfileEditScreen]'s docstring, points 2–4, for the
/// change-detection and re-seeding rules this implements.
class _BusinessProfileEditForm extends ConsumerStatefulWidget {
  const _BusinessProfileEditForm({super.key, required this.profile});

  final BusinessProfile profile;

  @override
  ConsumerState<_BusinessProfileEditForm> createState() =>
      _BusinessProfileEditFormState();
}

class _BusinessProfileEditFormState
    extends ConsumerState<_BusinessProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _descriptionController;

  late BusinessType _businessType;

  /// E.164 (e.g. `"+201001234567"`) or `null` for "no phone number",
  /// exactly like the entity's own `phoneNumber` field. Seeded from the
  /// current profile and updated from [IntlPhoneField.onChanged] on
  /// every keystroke, the same way the onboarding screen does it.
  String? _phoneNumber;

  bool _isSubmitting = false;

  /// Backend-driven, field-specific error text — set only from a
  /// [ValidationFailure]'s `fields` map (Part P-004), keyed by the real
  /// backend field names confirmed in Parts P-026/P-027
  /// (`business_name`, `business_type`, `country`, `city`,
  /// `description`, `phone_number`). Mirrors
  /// `BusinessOnboardingScreen`'s exact convention, including rendering
  /// `business_type`/`phone_number` errors as a plain [Text] beneath
  /// their control, since neither plugs into [_formKey] the way an
  /// [AppTextField] does.
  String? _businessNameError;
  String? _businessTypeError;
  String? _countryError;
  String? _cityError;
  String? _descriptionError;
  String? _phoneNumberError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _businessNameController = TextEditingController(text: profile.businessName);
    _countryController = TextEditingController(text: profile.country);
    _cityController = TextEditingController(text: profile.city);
    _descriptionController = TextEditingController(text: profile.description);
    _businessType = profile.businessType;
    _phoneNumber = profile.phoneNumber;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearBackendErrors() {
    _businessNameError = null;
    _businessTypeError = null;
    _countryError = null;
    _cityError = null;
    _descriptionError = null;
    _phoneNumberError = null;
    _generalError = null;
  }

  Future<void> _submit() async {
    // Clear any previous backend-driven errors before re-validating, so
    // a field the user has since fixed doesn't keep showing a stale
    // server-side complaint — same convention as LoginScreen/
    // RegisterScreen/BusinessOnboardingScreen.
    setState(_clearBackendErrors);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final original = widget.profile;

    final businessName = _businessNameController.text.trim();
    final country = _countryController.text.trim();
    final city = _cityController.text.trim();
    final description = _descriptionController.text.trim();

    // --- Change detection (see this screen's docstring, points 2-3) ---
    final changedBusinessName = businessName == original.businessName
        ? null
        : businessName;
    final changedBusinessType = _businessType == original.businessType
        ? null
        : _businessType;
    final changedCountry = country == original.country ? null : country;
    final changedCity = city == original.city ? null : city;

    // `description` is non-nullable on the entity (defaults to '') but
    // nullable on the backend, so "emptied" means "clear it", and an
    // unchanged value means "leave it alone" entirely.
    final Patchable<String> patchDescription;
    if (description == original.description) {
      patchDescription = const Patchable<String>.unset();
    } else if (description.isEmpty) {
      patchDescription = const Patchable<String>.clear();
    } else {
      patchDescription = Patchable<String>.value(description);
    }

    final phoneNumber = _phoneNumber;
    final Patchable<String> patchPhoneNumber;
    if (phoneNumber == original.phoneNumber) {
      patchPhoneNumber = const Patchable<String>.unset();
    } else if (phoneNumber == null || phoneNumber.isEmpty) {
      patchPhoneNumber = const Patchable<String>.clear();
    } else {
      patchPhoneNumber = Patchable<String>.value(phoneNumber);
    }

    final hasChanges =
        changedBusinessName != null ||
        changedBusinessType != null ||
        changedCountry != null ||
        changedCity != null ||
        patchDescription.isSet ||
        patchPhoneNumber.isSet;

    // Captured before the first await — the widget can legitimately be
    // rebuilt (and this State disposed) by the re-seed that follows a
    // successful save, so `context` must not be read afterwards.
    final messenger = ScaffoldMessenger.of(context);

    if (!hasChanges) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(businessProfileProvider.notifier)
          .updateProfile(
            businessName: changedBusinessName,
            businessType: changedBusinessType,
            country: changedCountry,
            city: changedCity,
            description: patchDescription,
            phoneNumber: patchPhoneNumber,
            // categoryId deliberately left at its `Patchable.unset()`
            // default — see this screen's docstring, point 1.
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Business profile updated.')),
      );
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
      // so the field-error strings just set above actually render on
      // the AppTextField-backed fields. business_type/phone_number
      // aren't Form-validated fields (see the field docstring above);
      // their Text widgets already reflect the state set above.
      _formKey.currentState?.validate();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
                  if (_businessNameError != null) return _businessNameError;
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
              // ⚠️ Pre-filling an existing E.164 number — verify on the
              // real machine. `intl_phone_field` 3.2.0 derives the
              // country from `initialValue` itself when it starts with
              // `+` and no `initialCountryCode` is given, which is why
              // `initialCountryCode` is passed ONLY for a profile with
              // no phone number yet (where 'EG' is the same placeholder
              // default the onboarding screen uses — Part P-028B). This
              // was read from the package's source, but could not be
              // executed in the authoring environment (no Flutter SDK —
              // the same documented gap every sandbox-authored part in
              // this project has). If the real run shows the wrong flag
              // or the country code duplicated inside the field, the
              // fallback is to keep `initialCountryCode: 'EG'` always
              // and strip the leading dial code from `initialValue`
              // before passing it — flag it back rather than changing
              // the entity/repository contract, which is confirmed
              // correct.
              IntlPhoneField(
                key: const ValueKey('business_profile_edit_phone_field'),
                initialValue: widget.profile.phoneNumber,
                initialCountryCode: widget.profile.phoneNumber == null
                    ? 'EG'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Phone number (optional)',
                  border: OutlineInputBorder(),
                ),
                invalidNumberMessage:
                    'Enter a valid phone number for the selected country.',
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: 'Save changes',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}