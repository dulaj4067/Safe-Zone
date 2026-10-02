import 'package:flutter/foundation.dart';

import '../models/shelter.dart';

/// "Show this on the home map" requests from anywhere in the app. AppShell
/// switches to the Home tab; the home map moves to the shelter and opens
/// its preview card. [requestId] changes on every request, so asking for
/// the same shelter twice still re-centres the map.
class MapFocusProvider extends ChangeNotifier {
  Shelter? _shelter;
  int _requestId = 0;

  Shelter? get shelter => _shelter;
  int get requestId => _requestId;

  void focusShelter(Shelter shelter) {
    _shelter = shelter;
    _requestId++;
    notifyListeners();
  }
}
