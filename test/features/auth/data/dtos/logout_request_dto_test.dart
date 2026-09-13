import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/data/dtos/logout_request_dto.dart';

void main() {
  test(
    'toJson sends only the refresh token — access goes in the header, not the body',
    () {
      const dto = LogoutRequestDto(refresh: 'refresh-token-value');

      expect(dto.toJson(), {'refresh': 'refresh-token-value'});
    },
  );
}
