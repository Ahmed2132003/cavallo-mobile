import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/data/dtos/business_profile_response_dto.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';

Map<String, dynamic> _profileJson({Object? avatar = 'absent'}) => {
  'id': 7,
  'business_name': 'Acme',
  'business_type': 'trader',
  'country': 'Egypt',
  'city': 'Cairo',
  'description': '',
  'phone_number': '',
  'category': null,
  'is_verified': false,
  'follower_count': 0,
  if (avatar != 'absent') 'avatar': avatar,
};

void main() {
  group('BusinessProfileResponseDto avatar', () {
    test('reads the avatar URL', () {
      final dto = BusinessProfileResponseDto.fromJson(
        _profileJson(avatar: 'https://cdn.example/a.png?sig=1'),
      );
      expect(dto.avatarUrl, 'https://cdn.example/a.png?sig=1');
      expect(dto.toJson()['avatar'], 'https://cdn.example/a.png?sig=1');
    });

    test('null, empty and missing avatar all mean no photo', () {
      expect(
        BusinessProfileResponseDto.fromJson(_profileJson(avatar: null)).avatarUrl,
        isNull,
      );
      expect(
        BusinessProfileResponseDto.fromJson(_profileJson(avatar: '')).avatarUrl,
        isNull,
      );
      final missing = BusinessProfileResponseDto.fromJson(_profileJson());
      expect(missing.avatarUrl, isNull);
      expect(missing.toJson().containsKey('avatar'), isFalse);
    });
  });

  group('BusinessProfile.withAvatarUrl', () {
    const profile = BusinessProfile(
      id: 1,
      businessName: 'Acme',
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
      avatarUrl: 'https://cdn.example/old.png',
    );

    test('sets a new photo and keeps every other field', () {
      final next = profile.withAvatarUrl('https://cdn.example/new.png');
      expect(next.avatarUrl, 'https://cdn.example/new.png');
      expect(next.businessName, 'Acme');
      expect(next.id, 1);
      expect(next == profile, isFalse);
    });

    test('null removes the photo (copyWith cannot)', () {
      expect(profile.withAvatarUrl(null).avatarUrl, isNull);
      expect(profile.copyWith(avatarUrl: null).avatarUrl, profile.avatarUrl);
    });
  });

  group('chat payloads', () {
    test('ConversationParticipantSummary reads avatar', () {
      final withPhoto = ConversationParticipantSummary.fromJson({
        'id': 2,
        'account_type': 'business',
        'display_name': 'Acme',
        'avatar': 'https://cdn.example/a.png',
      });
      final without = ConversationParticipantSummary.fromJson({
        'id': 3,
        'account_type': 'customer',
        'display_name': 'Sam',
        'avatar': null,
      });
      expect(withPhoto.avatarUrl, 'https://cdn.example/a.png');
      expect(without.avatarUrl, isNull);
    });

    test('SharedContent reads business_avatar', () {
      final shared = SharedContent.tryParse({
        'content_type': 'post',
        'object_id': 5,
        'available': true,
        'business_id': 7,
        'business_name': 'Acme',
        'business_avatar': 'https://cdn.example/a.png',
        'preview': null,
      });
      expect(shared?.businessAvatarUrl, 'https://cdn.example/a.png');
    });
  });
}
