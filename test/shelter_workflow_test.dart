import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/models/coordination_message.dart';
import 'package:safezone/models/shelter.dart';

Map<String, dynamic> _row({String? approval}) => {
      'id': 's1',
      'name': 'Town Hall',
      'location': {
        'coordinates': [79.9, 6.95],
      },
      'capacity': 120,
      'approval_status': ?approval,
    };

void main() {
  messagingTests();
  group('Shelter approval workflow', () {
    test('rows from a database without the migration read as approved', () {
      expect(Shelter.fromMap(_row()).approval, ShelterApproval.approved);
    });

    test('pending and rejected submissions are parsed', () {
      expect(Shelter.fromMap(_row(approval: 'pending')).approval, ShelterApproval.pending);
      final rejected = Shelter.fromMap({
        ..._row(approval: 'rejected'),
        'rejection_reason': 'Location does not match the address',
        'submitted_by': 'u1',
      });
      expect(rejected.approval, ShelterApproval.rejected);
      expect(rejected.rejectionReason, 'Location does not match the address');
      expect(rejected.submittedBy, 'u1');
    });

    test('every status has a readable label', () {
      for (final a in ShelterApproval.values) {
        expect(a.label, isNotEmpty);
      }
    });
  });
}

// Messaging read state, in the same file as the other shelter-branch tests.
void messagingTests() {
  group('Shelter messaging read state', () {
    CoordinationMessage msg({String? readAt, String to = 'me'}) => CoordinationMessage.fromMap({
          'id': 'm1',
          'shelter_id': 's1',
          'sender_id': 'other',
          'recipient_id': to,
          'message': 'hi',
          'created_at': '2026-10-15T10:00:00Z',
          'read_at': readAt,
        });

    test('a message to me with no read_at is unread', () {
      expect(msg().isUnreadFor('me'), isTrue);
    });

    test('a read message, or one I sent, is not unread', () {
      expect(msg(readAt: '2026-10-15T10:05:00Z').isUnreadFor('me'), isFalse);
      expect(msg(to: 'other').isUnreadFor('other'), isTrue);
      expect(msg().isUnreadFor('other'), isFalse);
    });

    test('rows without the read_at column parse as unread', () {
      final m = CoordinationMessage.fromMap({
        'id': 'm2',
        'sender_id': 'other',
        'recipient_id': 'me',
        'message': 'hello',
        'created_at': '2026-10-15T10:00:00Z',
      });
      expect(m.readAt, isNull);
    });
  });
}
