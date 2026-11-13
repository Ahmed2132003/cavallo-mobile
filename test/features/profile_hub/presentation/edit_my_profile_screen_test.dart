import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/core/widgets/error_state_widget.dart';
import 'package:social_commerce_app/features/auth/domain/user_entity.dart';
import 'package:social_commerce_app/features/auth/presentation/session_provider.dart';
import 'package:social_commerce_app/features/business_profile/presentation/business_avatar_picker.dart';
import 'package:social_commerce_app/features/profile_hub/presentation/edit_my_profile_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// 1x1 PNG (real magic bytes, so it passes the type check).
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

User _user({
  AccountType type = AccountType.customer,
  bool moderator = false,
  bool staff = false,
  String name = 'Old Name',
  String? avatar,
}) => User(
  id: 1,
  email: 'user@example.com',
  accountType: type,
  isModerator: moderator,
  isStaff: staff,
  displayName: name,
  avatarUrl: avatar,
);

class _FakeSession extends SessionNotifier {
  _FakeSession(this._user, {this.error});

  final User? _user;
  Object? error;
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<User?> build() async => _user;

  void fail() =>
      state = AsyncValue<User?>.error(Exception('x'), StackTrace.empty);

  @override
  Future<void> updateMyProfile({
    String? displayName,
    List<int>? avatarBytes,
    String? avatarFilename,
    bool removeAvatar = false,
  }) async {
    calls.add(<String, Object?>{
      'displayName': displayName,
      'avatarBytes': avatarBytes,
      'avatarFilename': avatarFilename,
      'removeAvatar': removeAvatar,
    });
    if (error != null) throw error!;
    final User cur = state.value!;
    state = AsyncValue<User?>.data(
      cur.withProfile(
        displayName: displayName ?? cur.displayName,
        avatarUrl:
            removeAvatar
                ? null
                : (avatarBytes != null
                    ? 'https://cdn.example/new.png'
                    : cur.avatarUrl),
      ),
    );
  }
}

class _GatedSession extends SessionNotifier {
  _GatedSession(this.gate);

  final Completer<User?> gate;

  @override
  Future<User?> build() => gate.future;
}

Future<_FakeSession> _pump(
  WidgetTester tester, {
  required User user,
  Future<PickedAvatar?> Function()? picker,
  Object? error,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final _FakeSession session = _FakeSession(user, error: error);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => session),
        if (picker != null)
          editProfileAvatarPickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        home: const EditMyProfileScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

Future<void> _pickPhotoViaSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('edit_profile_avatar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('edit_profile_pick')));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('edit_profile_save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loading: skeleton, then the form', (tester) async {
    final Completer<User?> gate = Completer<User?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => _GatedSession(gate))],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const EditMyProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppShimmerBox), findsWidgets);

    gate.complete(_user());
    await tester.pumpAndSettle();
    expect(find.byType(AppShimmerBox), findsNothing);
    expect(find.text('Display name'), findsOneWidget);
  });

  testWidgets('a session error shows the shared error state', (tester) async {
    final _FakeSession session = await _pump(tester, user: _user());
    session.fail();
    await tester.pump();
    expect(find.byType(ErrorStateWidget), findsOneWidget);
  });

  for (final ({String label, User user}) c in <({String label, User user})>[
    (label: 'customer', user: _user()),
    (label: 'business', user: _user(type: AccountType.business)),
    (label: 'moderator', user: _user(moderator: true)),
    (label: 'staff', user: _user(staff: true)),
  ]) {
    testWidgets('${c.label}: title, seeded name and email', (tester) async {
      await _pump(tester, user: c.user);
      expect(find.text('Edit my profile'), findsOneWidget);
      expect(find.text('Old Name'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
    });
  }

  testWidgets('editing the name sends only display_name', (tester) async {
    final _FakeSession session = await _pump(tester, user: _user());
    await tester.enterText(find.byType(TextFormField), '  New Name ');
    await _save(tester);

    expect(session.calls, hasLength(1));
    expect(session.calls.single['displayName'], 'New Name');
    expect(session.calls.single['avatarBytes'], isNull);
    expect(session.calls.single['removeAvatar'], false);
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('no changes: no request, a message', (tester) async {
    final _FakeSession session = await _pump(tester, user: _user());
    await _save(tester);

    expect(session.calls, isEmpty);
    expect(find.text('No changes to save.'), findsOneWidget);
  });

  testWidgets('a name over 80 characters is rejected on the device', (
    tester,
  ) async {
    final _FakeSession session = await _pump(tester, user: _user());
    await tester.enterText(find.byType(TextFormField), 'a' * 81);
    await _save(tester);

    expect(session.calls, isEmpty);
    expect(
      find.text('Display name must be 80 characters or fewer.'),
      findsOneWidget,
    );
  });

  testWidgets('uploading a photo sends its bytes', (tester) async {
    final _FakeSession session = await _pump(
      tester,
      user: _user(),
      picker: () async => PickedAvatar(bytes: _png, filename: 'me.png'),
    );
    await _pickPhotoViaSheet(tester);
    await _save(tester);

    expect(session.calls, hasLength(1));
    expect(session.calls.single['avatarBytes'], _png);
    expect(session.calls.single['avatarFilename'], 'me.png');
    expect(session.calls.single['displayName'], isNull);
  });

  testWidgets('a fake file (wrong type) is rejected with a message', (
    tester,
  ) async {
    final _FakeSession session = await _pump(
      tester,
      user: _user(),
      picker:
          () async => PickedAvatar(
            bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
            filename: 'virus.jpg',
          ),
    );
    await _pickPhotoViaSheet(tester);
    expect(find.text('Choose a JPEG, PNG or WebP image.'), findsOneWidget);
    await _save(tester);
    expect(session.calls, isEmpty);
  });

  testWidgets('a photo over 5 MB is rejected with a message', (tester) async {
    final Uint8List big = Uint8List(kMaxAvatarBytes + 1)
      ..setRange(0, _png.length, _png);
    final _FakeSession session = await _pump(
      tester,
      user: _user(),
      picker: () async => PickedAvatar(bytes: big, filename: 'big.png'),
    );
    await _pickPhotoViaSheet(tester);
    expect(find.text('Photo is too large (max 5 MB).'), findsOneWidget);
    await _save(tester);
    expect(session.calls, isEmpty);
  });

  testWidgets('removing the saved photo sends remove_avatar', (tester) async {
    final _FakeSession session = await _pump(
      tester,
      user: _user(avatar: 'https://cdn.example/old.png'),
    );
    await tester.tap(find.byKey(const Key('edit_profile_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_profile_remove')));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(session.calls.single['removeAvatar'], true);
    expect(session.calls.single['avatarBytes'], isNull);
  });

  testWidgets('no remove option when there is no photo', (tester) async {
    await _pump(tester, user: _user());
    await tester.tap(find.byKey(const Key('edit_profile_avatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit_profile_pick')), findsOneWidget);
    expect(find.byKey(const Key('edit_profile_remove')), findsNothing);
  });

  testWidgets('a network failure shows a localized message, never raw text', (
    tester,
  ) async {
    final _FakeSession session = await _pump(
      tester,
      user: _user(),
      error: DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const NetworkFailure(
          message: 'RAW BACKEND TEXT',
          code: ApiErrorCodes.networkError,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'New Name');
    await _save(tester);

    expect(session.calls, hasLength(1));
    expect(
      find.text('No connection. Check your internet and try again.'),
      findsOneWidget,
    );
    expect(find.text('RAW BACKEND TEXT'), findsNothing);
    // The typed edit is still there for a retry.
    expect(find.text('New Name'), findsOneWidget);
  });

  testWidgets('a 400 on the avatar field shows the photo message', (
    tester,
  ) async {
    await _pump(
      tester,
      user: _user(),
      error: DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const ValidationFailure(
          message: 'raw',
          fields: <String, List<String>>{
            'avatar': <String>['raw'],
          },
          code: 'VALIDATION_ERROR',
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'New Name');
    await _save(tester);

    expect(
      find.text('The server could not accept this photo. Try a different one.'),
      findsOneWidget,
    );
  });

  testWidgets('Arabic + dark: RTL, Arabic texts, no exceptions', (
    tester,
  ) async {
    await _pump(
      tester,
      user: _user(),
      locale: const Locale('ar'),
      theme: AppTheme.dark,
    );

    expect(find.text('تعديل ملفي الشخصي'), findsOneWidget);
    expect(find.text('حفظ التغييرات'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(EditMyProfileScreen))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
