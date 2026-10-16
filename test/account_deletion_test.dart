import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/services/account_deletion_service.dart';

void main() {
  group('DeletionRequest', () {
    test('no row means no request', () {
      final r = DeletionRequest.fromRow(null);
      expect(r.status, DeletionStatus.none);
      expect(r.isOpen, isFalse);
    });

    test('received and processing are open; completed and cancelled are not', () {
      for (final (status, open) in [
        ('awaiting_email', true),
        ('received', true),
        ('processing', true),
        ('completed', false),
        ('cancelled', false),
      ]) {
        final r = DeletionRequest.fromRow({'status': status, 'requested_at': '2026-10-14T10:00:00Z'});
        expect(r.isOpen, open, reason: status);
        expect(r.requestedAt, isNotNull);
      }
    });

    test('awaiting_email reads as waiting for the citizen, not for an administrator', () {
      final r = DeletionRequest.fromRow({'status': 'awaiting_email'});
      expect(r.status, DeletionStatus.awaitingEmail);
      expect(r.isOpen, isTrue);
    });

    test('an unknown status is treated as an open request, never as deleted', () {
      final r = DeletionRequest.fromRow({'status': 'weird'});
      expect(r.status, DeletionStatus.received);
    });
  });

  group('confirmation code', () {
    test('only exactly six digits are valid', () {
      expect(isValidDeletionCode('123456'), isTrue);
      expect(isValidDeletionCode(' 123456 '), isTrue);
      for (final bad in ['12345', '1234567', '12345a', '12 456', '', null]) {
        expect(isValidDeletionCode(bad), isFalse, reason: '$bad');
      }
    });

    test('server results map to outcomes; anything unknown is never "confirmed"', () {
      expect(DeletionCodeResult.fromServer('confirmed'), DeletionCodeResult.confirmed);
      expect(DeletionCodeResult.fromServer('wrong'), DeletionCodeResult.wrong);
      expect(DeletionCodeResult.fromServer('expired'), DeletionCodeResult.expired);
      expect(DeletionCodeResult.fromServer('too_many'), DeletionCodeResult.tooManyTries);
      expect(DeletionCodeResult.fromServer('no_code'), DeletionCodeResult.noCode);
      expect(DeletionCodeResult.fromServer(null), DeletionCodeResult.noRequest);
      expect(DeletionCodeResult.fromServer('surprise'), isNot(DeletionCodeResult.confirmed));
    });
  });

  group('OpenDeletionRequest', () {
    test('falls back to a neutral name when the profile is gone', () {
      final r = OpenDeletionRequest.fromRow({
        'id': 'r1',
        'user_id': null,
        'full_name': null,
        'status': 'processing',
        'reason': 'moving away',
        'requested_at': '2026-10-14T10:00:00Z',
      });
      expect(r.name, 'Unnamed account');
      expect(r.status, DeletionStatus.processing);
      expect(r.reason, 'moving away');
    });
  });
}
