import 'package:flutter_test/flutter_test.dart';

import 'package:safezone/models/coordination_message.dart';
import 'package:safezone/models/feedback_entry.dart';
import 'package:safezone/models/shelter_resource.dart';
import 'package:safezone/models/volunteer_task.dart';

void main() {
  group('ShelterResource', () {
    test('parses a seed row and formats whole and fractional quantities', () {
      final water = ShelterResource.fromMap({
        'id': 'r1',
        'shelter_id': 's1',
        'resource_type': 'water',
        'quantity': 500,
        'unit': 'liters',
        'updated_at': '2026-08-19T13:05:34.154578+00:00',
      });
      expect(water.type, ResourceType.water);
      expect(water.quantityLabel, '500 liters');

      final food = ShelterResource.fromMap({
        'id': 'r2',
        'shelter_id': 's1',
        'resource_type': 'food',
        'quantity': 12.5,
        'unit': 'meal_packs',
      });
      expect(food.quantityLabel, '12.5 meal packs');
      expect(food.updatedAt, isNull);
    });

    test('unknown resource types fall back to other', () {
      expect(ResourceType.fromDb('fuel'), ResourceType.other);
      expect(ResourceType.fromDb(null), ResourceType.other);
    });
  });

  group('VolunteerTask', () {
    test('round-trips every status through its database value', () {
      for (final status in VolunteerTaskStatus.values) {
        expect(VolunteerTaskStatus.fromDb(status.dbValue), status);
      }
      expect(VolunteerTaskStatus.inProgress.dbValue, 'in_progress');
    });

    test('counts embedded assignments and knows who signed up', () {
      final task = VolunteerTask.fromMap({
        'id': 't1',
        'title': 'Distribute food packs',
        'volunteers_needed': 2,
        'status': 'open',
        'created_at': '2026-08-24T09:35:01.671193+00:00',
        'volunteer_assignments': [
          {'volunteer_id': 'u1'},
          {'volunteer_id': 'u2'},
        ],
      });
      expect(task.signedUpCount, 2);
      expect(task.isFull, isTrue);
      expect(task.isSignedUp('u1'), isTrue);
      expect(task.isSignedUp('u3'), isFalse);
      expect(task.isSignedUp(null), isFalse);
    });

    test('a task with no assignments key has zero sign-ups', () {
      final task = VolunteerTask.fromMap({
        'id': 't2',
        'title': 'Sandbagging',
        'volunteers_needed': 5,
        'status': 'in_progress',
        'created_at': '2026-08-24T09:35:01Z',
      });
      expect(task.signedUpCount, 0);
      expect(task.isFull, isFalse);
      expect(task.status, VolunteerTaskStatus.inProgress);
    });
  });

  group('CoordinationMessage', () {
    final msg = CoordinationMessage.fromMap({
      'id': 'm1',
      'shelter_id': 's1',
      'sender_id': 'citizen',
      'recipient_id': 'manager',
      'message': 'Is there space for a family of four?',
      'created_at': '2026-09-27T10:00:00Z',
    });

    test('identifies the other party from either side', () {
      expect(msg.otherParty('citizen'), 'manager');
      expect(msg.otherParty('manager'), 'citizen');
    });

    test('belongs to its thread regardless of direction', () {
      expect(msg.isBetween('citizen', 'manager'), isTrue);
      expect(msg.isBetween('manager', 'citizen'), isTrue);
      expect(msg.isBetween('citizen', 'someone-else'), isFalse);
    });
  });

  test('FeedbackEntry parses optional fields', () {
    final entry = FeedbackEntry.fromMap({
      'id': 'f1',
      'submitted_by': 'u1',
      'rating': 4,
      'needs': null,
      'zone_id': null,
      'created_at': '2026-09-27T10:00:00Z',
    });
    expect(entry.rating, 4);
    expect(entry.needs, isNull);
  });
}
