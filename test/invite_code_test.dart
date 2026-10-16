import 'package:flutter_test/flutter_test.dart';
import 'package:safezone/utils/error_messages.dart';
import 'package:safezone/utils/validators.dart';

void main() {
  test('invite codes are cleaned and checked', () {
    expect(normalizeInviteCode('3f9a-1c7b 20de'), '3F9A1C7B20DE');
    expect(normalizeInviteCode('short'), isNull);
    expect(normalizeInviteCode(null), isNull);
    expect(normalizeInviteCode('3F9A1C7B20D!'), isNull);
  });

  test('friendlyError never leaks raw exception text', () {
    expect(friendlyError(Exception('boom: secret')), isNot(contains('secret')));
  });
}
