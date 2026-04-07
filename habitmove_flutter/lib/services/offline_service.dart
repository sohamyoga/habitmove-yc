import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// OfflineService
///
/// Provides:
///  - SQLite-backed cache for courses, dashboard, my-courses, certificates
///  - Connectivity stream so UI can react to online/offline state
///  - Download queue: tracks which courses are saved for offline
///  - Helpers: isCached(), saveForOffline(), clearCache()

class OfflineService {
  OfflineService._();
  static final OfflineService instance = OfflineService._();

  Database? _db;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _db = await _openDb();

    // Seed connectivity state
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    // Stream connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (_isOnline != wasOnline) {
        debugPrint('[Offline] Connectivity changed → online=$_isOnline');
      }
    });
  }

  // ─── Database ─────────────────────────────────────────────────────────────

  Future<Database> _openDb() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'habitmove_cache.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cache (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            saved_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_courses (
            course_id   INTEGER PRIMARY KEY,
            course_json TEXT NOT NULL,
            saved_at    INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ─── Generic key/value cache ──────────────────────────────────────────────

  /// Save any JSON-serialisable object under [key].
  Future<void> save(String key, dynamic value) async {
    await _db?.insert(
      'cache',
      {
        'key': key,
        'value': jsonEncode(value),
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load cached value for [key]. Returns null if not found or expired.
  Future<dynamic> load(String key, {Duration maxAge = const Duration(hours: 6)}) async {
    final rows = await _db?.query('cache', where: 'key = ?', whereArgs: [key]);
    if (rows == null || rows.isEmpty) return null;
    final row = rows.first;
    final savedAt = row['saved_at'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    if (age > maxAge.inMilliseconds) return null;
    return jsonDecode(row['value'] as String);
  }

  Future<void> delete(String key) async =>
      _db?.delete('cache', where: 'key = ?', whereArgs: [key]);

  Future<void> clearAll() async {
    await _db?.delete('cache');
    await _db?.delete('offline_courses');
  }

  // ─── Offline course saving ─────────────────────────────────────────────────

  Future<void> saveForOffline(Map<String, dynamic> courseJson) async {
    final id = courseJson['id'] as int?;
    if (id == null) return;
    await _db?.insert(
      'offline_courses',
      {
        'course_id': id,
        'course_json': jsonEncode(courseJson),
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('[Offline] Saved course $id for offline access');
  }

  Future<void> removeOfflineCourse(int courseId) async =>
      _db?.delete('offline_courses', where: 'course_id = ?', whereArgs: [courseId]);

  Future<bool> isCourseOffline(int courseId) async {
    final rows = await _db?.query(
      'offline_courses', where: 'course_id = ?', whereArgs: [courseId]);
    return (rows?.isNotEmpty) ?? false;
  }

  Future<List<Map<String, dynamic>>> getOfflineCourses() async {
    final rows = await _db?.query('offline_courses', orderBy: 'saved_at DESC') ?? [];
    return rows.map((r) => jsonDecode(r['course_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<int> get offlineCourseCount async =>
      (await _db?.query('offline_courses'))?.length ?? 0;

  // ─── Cache size ────────────────────────────────────────────────────────────

  Future<String> get cacheSizeString async {
    final cacheRows = await _db?.query('cache') ?? [];
    final courseRows = await _db?.query('offline_courses') ?? [];
    final bytes = [
      ...cacheRows.map((r) => (r['value'] as String).length),
      ...courseRows.map((r) => (r['course_json'] as String).length),
    ].fold<int>(0, (a, b) => a + b);
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
