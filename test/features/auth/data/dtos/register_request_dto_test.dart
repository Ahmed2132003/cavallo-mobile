import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/data/dtos/register_request_dto.dart';

void main() {
  test('toJson matches the backend field names exactly', () {
    const dto = RegisterRequestDto(
      email: 'trader@example.com',
      password: 'S3curePass!',
      passwordConfirm: 'S3curePass!',
      accountType: 'business',
    );

    expect(dto.toJson(), {
      'email': 'trader@example.com',
      'password': 'S3curePass!',
      'password_confirm': 'S3curePass!',
      'account_type': 'business',
    });
  });
}
