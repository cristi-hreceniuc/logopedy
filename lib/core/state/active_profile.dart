// lib/core/state/active_profile.dart
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';

class ActiveProfileService extends ChangeNotifier {
  ActiveProfileService(this._store);
  final SecureStore _store;

  static const _kKey = 'active_profile_id';
  int? _id;
  int? get id => _id;
  bool get hasActive => _id != null;

  Future<void> load() async {
    final raw = await _store.readKey(_kKey);
    _id = raw == null ? null : int.tryParse(raw);
    notifyListeners();
  }

  Future<void> set(int id) async {
    _id = id;
    await _store.writeKey(_kKey, id.toString());
    notifyListeners();
  }

  Future<void> clear() async {
    _id = null;
    await _store.deleteKey(_kKey);
    notifyListeners();
  }
}
