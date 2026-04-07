import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';

/// OfflineCacheService
///
/// Stores API responses locally using Hive so the app works without network.
/// Uses a simple key-value structure with TTL metadata.
///
/// Boxes:
///   'courses'     — list of CourseModel JSON
///   'my_courses'  — enrolled courses JSON
///   'dashboard'   — dashboard JSON
///   'quizzes'     — available quizzes JSON
///   'meta'        — cache timestamps

class OfflineCacheService {
  OfflineCacheService._();
  static final OfflineCacheService instance = OfflineCacheService._();

  static const _ttlMinutes = 60; // cache lives for 60 minutes

  Box? _courses;
  Box? _myCourses;
  Box? _dashboard;
  Box? _quizzes;
  Box? _meta;

  bool _online = true;
  bool get isOnline => _online;

  final _connectivity = Connectivity();
  final _onlineNotifier = ValueNotifier<bool>(true);
  ValueNotifier<bool> get onlineNotifier => _onlineNotifier;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Hive.initFlutter();
    _courses   = await Hive.openBox('courses');
    _myCourses = await Hive.openBox('my_courses');
    _dashboard = await Hive.openBox('dashboard');
    _quizzes   = await Hive.openBox('quizzes');
    _meta      = await Hive.openBox('cache_meta');

    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _setOnline(result.first != ConnectivityResult.none);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) {
      _setOnline(results.first != ConnectivityResult.none);
    });
  }

  void _setOnline(bool online) {
    _online = online;
    _onlineNotifier.value = online;
    debugPrint('[Cache] Network: ${online ? "online" : "offline"}');
  }

  // ─── Courses ──────────────────────────────────────────────────────────────

  Future<void> saveCourses(List<CourseModel> courses) async {
    await _courses?.put('list', jsonEncode(courses.map((c) => _courseToJson(c)).toList()));
    await _stampNow('courses');
  }

  List<CourseModel>? getCourses() {
    if (_isExpired('courses')) return null;
    final raw = _courses?.get('list');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).map((j) => CourseModel.fromJson(j)).toList();
    } catch (_) { return null; }
  }

  Future<void> saveMyCourses(List<CourseModel> courses) async {
    await _myCourses?.put('list', jsonEncode(courses.map((c) => _courseToJson(c)).toList()));
    await _stampNow('my_courses');
  }

  List<CourseModel>? getMyCourses() {
    if (_isExpired('my_courses')) return null;
    final raw = _myCourses?.get('list');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).map((j) => CourseModel.fromJson(j)).toList();
    } catch (_) { return null; }
  }

  // ─── Dashboard ────────────────────────────────────────────────────────────

  Future<void> saveDashboard(Map<String, dynamic> data) async {
    await _dashboard?.put('data', jsonEncode(data));
    await _stampNow('dashboard');
  }

  Map<String, dynamic>? getDashboard() {
    if (_isExpired('dashboard')) return null;
    final raw = _dashboard?.get('data');
    if (raw == null) return null;
    try { return jsonDecode(raw); } catch (_) { return null; }
  }

  // ─── Quizzes ──────────────────────────────────────────────────────────────

  Future<void> saveQuizzes(List<QuizModel> quizzes) async {
    await _quizzes?.put('list', jsonEncode(quizzes.map((q) => {
      'id': q.id, 'title': q.title,
      'description': q.description,
      'total_questions': q.totalQuestions,
    }).toList()));
    await _stampNow('quizzes');
  }

  List<QuizModel>? getQuizzes() {
    if (_isExpired('quizzes')) return null;
    final raw = _quizzes?.get('list');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).map((j) => QuizModel.fromJson(j)).toList();
    } catch (_) { return null; }
  }

  // ─── Individual course cache ──────────────────────────────────────────────

  Future<void> saveCourseDetail(String id, Map<String, dynamic> data) async {
    await _courses?.put('detail_$id', jsonEncode(data));
    await _stampNow('detail_$id');
  }

  Map<String, dynamic>? getCourseDetail(String id) {
    if (_isExpired('detail_$id')) return null;
    final raw = _courses?.get('detail_$id');
    if (raw == null) return null;
    try { return jsonDecode(raw); } catch (_) { return null; }
  }

  // ─── TTL helpers ──────────────────────────────────────────────────────────

  Future<void> _stampNow(String key) async {
    await _meta?.put(key, DateTime.now().toIso8601String());
  }

  bool _isExpired(String key) {
    final raw = _meta?.get(key);
    if (raw == null) return true;
    try {
      final saved = DateTime.parse(raw);
      return DateTime.now().difference(saved).inMinutes > _ttlMinutes;
    } catch (_) { return true; }
  }

  // ─── Clear ────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _courses?.clear();
    await _myCourses?.clear();
    await _dashboard?.clear();
    await _quizzes?.clear();
    await _meta?.clear();
    debugPrint('[Cache] Cleared all cached data');
  }

  Future<void> clearExpired() async {
    for (final key in ['courses', 'my_courses', 'dashboard', 'quizzes']) {
      if (_isExpired(key)) {
        await _courses?.delete(key == 'courses' ? 'list' : key);
        await _meta?.delete(key);
      }
    }
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Map<String, dynamic> get stats => {
    'courses_cached': _courses?.length ?? 0,
    'my_courses_cached': (_myCourses?.get('list') != null) ? 1 : 0,
    'dashboard_cached': (_dashboard?.get('data') != null) ? 1 : 0,
    'quizzes_cached': (_quizzes?.get('list') != null) ? 1 : 0,
    'online': _online,
  };

  // ─── Helper ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _courseToJson(CourseModel c) => {
    'id': c.id, 'title': c.title, 'slug': c.slug,
    'plan': c.plan, 'price': c.price, 'discounted_price': c.discountedPrice,
    'banner': c.banner, 'short_description': c.shortDescription,
    'description': c.description,
    'category': c.category != null ? {'id': c.category!.id, 'name': c.category!.name} : null,
    'progress': c.progress, 'total_sessions': c.totalSessions,
    'completed_sessions': c.completedSessions,
  };
}
