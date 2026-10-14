import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/models/shelter.dart';

Map<String, dynamic> _row({String? approval}) => {
      'id': 's1',
      'name': 'Town Hall',
      'location': {
        'coordinates': [79.9, 6.95],
      },
      'capacity': 120,
      if (approval != null) 'approval_status': approval,
    };

void main() {
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
