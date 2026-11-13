import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/interceptors/error_interceptor.dart';
import 'package:social_commerce_app/features/profile_hub/data/my_profile_repository.dart';

import '../../chat/data/fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late MyProfileRepository repository;

  setUp(() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = FakeHttpClientAdapter();
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(ErrorInterceptor());
    repository = MyProfileRepository(dio: dio);
  });

  test(
    'a photo goes as multipart PATCH with display_name and avatar',
    () async {
      adapter.enqueue(
        statusCode: 200,
        data: <String, dynamic>{
          'display_name': 'Sam',
          'avatar': 'https://cdn.example/a.png',
        },
      );

      final MyProfileUpdate? result = await repository.update(
        displayName: 'Sam',
        avatarBytes: <int>[1, 2, 3],
        avatarFilename: 'a.png',
      );

      final RequestOptions options = adapter.requestedOptions.single;
      expect(options.method, 'PATCH');
      expect(options.path, '/api/v1/auth/me/profile/');
      expect(options.data, isA<FormData>());
      final FormData form = options.data as FormData;
      expect(
        <String, String>{
          for (final MapEntry<String, String> e in form.fields) e.key: e.value,
        },
        <String, String>{'display_name': 'Sam'},
      );
      expect(form.files.single.key, 'avatar');
      expect(form.files.single.value.filename, 'a.png');
      expect(result?.displayName, 'Sam');
      expect(result?.avatarUrl, 'https://cdn.example/a.png');
    },
  );

  test('without a photo it is plain JSON (no multipart)', () async {
    adapter.enqueue(
      statusCode: 200,
      data: <String, dynamic>{'display_name': 'Sam', 'avatar': null},
    );

    final MyProfileUpdate? result = await repository.update(displayName: 'Sam');

    final RequestOptions options = adapter.requestedOptions.single;
    expect(options.data, isNot(isA<FormData>()));
    expect(options.data, <String, dynamic>{'display_name': 'Sam'});
    expect(result?.avatarUrl, isNull);
  });

  test('remove_avatar is sent as JSON true', () async {
    adapter.enqueue(
      statusCode: 200,
      data: <String, dynamic>{'display_name': 'Sam', 'avatar': null},
    );

    await repository.update(removeAvatar: true);

    expect(adapter.requestedOptions.single.data, <String, dynamic>{
      'remove_avatar': true,
    });
  });

  test('a response without display_name/avatar returns null', () async {
    adapter.enqueue(statusCode: 200, data: <String, dynamic>{'detail': 'ok'});

    expect(await repository.update(displayName: 'Sam'), isNull);
  });

  test('a 400 surfaces as ValidationFailure with its fields', () async {
    adapter.enqueue(
      statusCode: 400,
      data: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'VALIDATION_ERROR',
          'message': 'Invalid',
          'fields': <String, dynamic>{
            'avatar': <String>['bad image'],
          },
        },
      },
    );

    try {
      await repository.update(avatarBytes: <int>[1], avatarFilename: 'x.png');
      fail('Expected a DioException');
    } on DioException catch (e) {
      expect(e.error, isA<ValidationFailure>());
      expect((e.error as ValidationFailure).fields['avatar'], <String>[
        'bad image',
      ]);
    }
  });
}
