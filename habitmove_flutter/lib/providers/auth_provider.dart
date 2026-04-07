import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _loading = false;
  String? _error;

  UserModel? get user   => _user;
  String?    get token  => _token;
  bool       get loading => _loading;
  String?    get error  => _error;
  bool       get isAuthenticated => _user != null && _token != null;

  static const _prefKey = 'habitmove_auth';

  // Rehydrate session from local storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _user  = UserModel.fromJson(map['user']);
        _token = map['token'];
        api.setToken(_token);
      } catch (_) {
        await prefs.remove(_prefKey);
      }
    }
    notifyListeners();
  }

  void _setLoading(bool v) { _loading = v; _error = null; notifyListeners(); }
  void _setError(String msg) { _loading = false; _error = msg; notifyListeners(); }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final data = await api.login(email, password);
      await _persist(data);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password, String confirmation) async {
    _setLoading(true);
    try {
      final data = await api.register(name, email, password, confirmation);
      await _persist(data);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try { await api.logout(); } catch (_) {}
    _user = null; _token = null;
    api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    notifyListeners();
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    _user  = UserModel.fromJson(data['user']);
    _token = data['token'];
    api.setToken(_token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode({'user': data['user'], 'token': _token}));
    _loading = false;
    _error = null;
  }

  void clearError() { _error = null; notifyListeners(); }
}
