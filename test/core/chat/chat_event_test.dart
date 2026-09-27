import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/chat/chat_event.dart';

void main() {
  group('ChatEvent.fromJson — chat_message (MessageReceived)', () {
    test('parses a well-formed raw Message payload', () {
      final json = {
        'id': 42,
        'conversation': 7,
        'sender': 3,
        'text': 'hello',
        'status': 'sent',
        'created_at': '2026-01-15T10:30:00Z',
      };

      final event = ChatEvent.fromJson(json);

      expect(event, isA<MessageReceived>());
      final message = event as MessageReceived;
      expect(message.id, 42);
      expect(message.conversationId, 7);
      expect(message.senderId, 3);
      expect(message.text, 'hello');
      expect(message.status, 'sent');
      expect(message.createdAt, DateTime.parse('2026-01-15T10:30:00Z'));
    });

    test(
      'throws ChatEventParseException when a field has the wrong type',
      () {
        final json = {
          'id': 'not-an-int',
          'conversation': 7,
          'sender': 3,
          'text': 'hello',
          'status': 'sent',
          'created_at': '2026-01-15T10:30:00Z',
        };

        expect(
          () => ChatEvent.fromJson(json),
          throwsA(isA<ChatEventParseException>()),
        );
      },
    );

    test(
      'throws ChatEventParseException when created_at is not valid ISO-8601',
      () {
        final json = {
          'id': 42,
          'conversation': 7,
          'sender': 3,
          'text': 'hello',
          'status': 'sent',
          'created_at': 'not-a-date',
        };

        expect(
          () => ChatEvent.fromJson(json),
          throwsA(isA<ChatEventParseException>()),
        );
      },
    );
  });

  group('ChatEvent.fromJson — status_update (StatusUpdate)', () {
    test('parses a delivered status update', () {
      final json = {'message_id': 99, 'status': 'delivered'};

      final event = ChatEvent.fromJson(json);

      expect(event, isA<StatusUpdate>());
      final update = event as StatusUpdate;
      expect(update.messageId, 99);
      expect(update.status, 'delivered');
    });

    test('parses a read status update', () {
      final json = {'message_id': 100, 'status': 'read'};

      final event = ChatEvent.fromJson(json);

      expect(event, isA<StatusUpdate>());
      expect((event as StatusUpdate).status, 'read');
    });

    test('throws ChatEventParseException when message_id is not an int', () {
      final json = {'message_id': '99', 'status': 'delivered'};

      expect(
        () => ChatEvent.fromJson(json),
        throwsA(isA<ChatEventParseException>()),
      );
    });
  });

  group('ChatEvent.fromJson — typing_indicator (TypingIndicator)', () {
    test('parses is_typing: true', () {
      final event = ChatEvent.fromJson({'is_typing': true});

      expect(event, isA<TypingIndicator>());
      expect((event as TypingIndicator).isTyping, isTrue);
    });

    test('parses is_typing: false', () {
      final event = ChatEvent.fromJson({'is_typing': false});

      expect(event, isA<TypingIndicator>());
      expect((event as TypingIndicator).isTyping, isFalse);
    });

    test('throws ChatEventParseException when is_typing is not a bool', () {
      final json = {'is_typing': 'yes'};

      expect(
        () => ChatEvent.fromJson(json),
        throwsA(isA<ChatEventParseException>()),
      );
    });
  });

  group('ChatEvent.fromJson — unrecognized shapes', () {
    test('throws ChatEventParseException for an empty object', () {
      expect(
        () => ChatEvent.fromJson(<String, dynamic>{}),
        throwsA(isA<ChatEventParseException>()),
      );
    });

    test('throws ChatEventParseException for a completely unrelated shape', () {
      final json = {'foo': 'bar'};

      expect(
        () => ChatEvent.fromJson(json),
        throwsA(isA<ChatEventParseException>()),
      );
    });

    test(
      'throws ChatEventParseException for a Message payload missing a '
      'required key',
      () {
        final json = {
          'id': 42,
          'conversation': 7,
          'sender': 3,
          'text': 'hello',
          'status': 'sent',
          // created_at missing on purpose
        };

        expect(
          () => ChatEvent.fromJson(json),
          throwsA(isA<ChatEventParseException>()),
        );
      },
    );
  });

  group('Equality', () {
    test('MessageReceived instances with identical fields are equal', () {
      final a = MessageReceived(
        id: 1,
        conversationId: 2,
        senderId: 3,
        text: 'hi',
        status: 'sent',
        createdAt: DateTime.parse('2026-01-15T10:30:00Z'),
      );
      final b = MessageReceived(
        id: 1,
        conversationId: 2,
        senderId: 3,
        text: 'hi',
        status: 'sent',
        createdAt: DateTime.parse('2026-01-15T10:30:00Z'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('StatusUpdate instances with identical fields are equal', () {
      expect(
        const StatusUpdate(messageId: 1, status: 'read'),
        equals(const StatusUpdate(messageId: 1, status: 'read')),
      );
    });

    test('TypingIndicator instances with identical fields are equal', () {
      expect(
        const TypingIndicator(isTyping: true),
        equals(const TypingIndicator(isTyping: true)),
      );
    });
  });
}