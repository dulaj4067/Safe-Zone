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

    test('an unknown status is treated as an open request, never as deleted', () {
      final r = DeletionRequest.fromRow({'status': 'weird'});
      expect(r.status, DeletionStatus.received);
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
