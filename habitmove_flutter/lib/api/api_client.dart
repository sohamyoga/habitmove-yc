import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const _base = 'https://habitmove.com/api/v1';
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$_base$path'), headers: _headers);
    return _handle(res);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (data is Map && data['errors'] != null) {
      final msgs = (data['errors'] as Map).values
          .expand((v) => v is List ? v : [v])
          .join(' ');
      throw ApiException(msgs);
    }
    throw ApiException(data['message'] ?? 'Request failed (${res.statusCode})');
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _post('/login', {'email': email, 'password': password});
    return data;
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password, String confirmation) async {
    final data = await _post('/register', {
      'name': name, 'email': email,
      'password': password, 'password_confirmation': confirmation,
    });
    return data;
  }

  Future<void> logout() async => _post('/logout');

  Future<void> forgotPassword(String email) async =>
      _post('/forgot-password', {'email': email});

  Future<UserModel> getUser() async {
    final data = await _get('/user');
    return UserModel.fromJson(data);
  }

  // ─── Courses ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCourses({String search = '', String category = ''}) async {
    final params = <String, String>{};
    if (search.isNotEmpty) params['search'] = search;
    if (category.isNotEmpty) params['category'] = category;
    final uri = Uri.parse('$_base/courses').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<Map<String, dynamic>> getCourse(String identifier) async {
    final data = await _get('/courses/$identifier');
    return data;
  }

  Future<CouponModel> checkCoupon(int courseId, String code) async {
    final data = await _post('/coupon/check-course/$courseId', {'code': code});
    return CouponModel.fromJson(data);
  }

  // ─── Checkout ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> enrollCourse({
    required String name,
    required String email,
    required int courseId,
    String paymentMethod = 'stripe',
    String? couponCode,
  }) async {
    final body = <String, dynamic>{
      'name': name, 'email': email,
      'course_id': courseId, 'payment_method': paymentMethod,
    };
    if (couponCode != null) body['coupon_code'] = couponCode;
    return await _post('/checkout/course', body);
  }

  // ─── User ──────────────────────────────────────────────────────────────────

  Future<DashboardModel> getDashboard() async {
    final data = await _get('/dashboard');
    return DashboardModel.fromJson(data);
  }

  Future<List<CourseModel>> getMyCourses() async {
    final data = await _get('/my-courses');
    final list = data['courses'] ?? data['data'] ?? [];
    return (list as List).map((c) => CourseModel.fromJson(c)).toList();
  }

  Future<List<CertificateModel>> getCertificates() async {
    final data = await _get('/certificates');
    final list = data['certificates'] ?? data['data'] ?? [];
    return (list as List).map((c) => CertificateModel.fromJson(c)).toList();
  }

  // ─── Membership ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMembership() async => _get('/membership');

  Future<Map<String, dynamic>> getMyMembership() async => _get('/my-membership');

  // ─── Quizzes ───────────────────────────────────────────────────────────────

  Future<List<QuizModel>> getAvailableQuizzes() async {
    final data = await _get('/quizzes/available');
    final list = data['quizzes'] ?? data['data'] ?? data;
    if (list is List) return list.map((q) => QuizModel.fromJson(q)).toList();
    return [];
  }

  Future<Map<String, dynamic>> startQuiz(int quizId) async =>
      _get('/quiz/$quizId/start');

  Future<QuizResult> submitQuiz(
      int attemptId, Map<String, dynamic> answers, int timeSpent) async {
    final data = await _post('/quiz/attempt/$attemptId/submit', {
      'answers': answers,
      'time_spent': timeSpent,
    });
    return QuizResult.fromJson(data['result'] ?? data);
  }

  Future<Map<String, dynamic>> getLeaderboard({int? quizId}) async {
    final path = quizId != null
        ? '/quiz/leaderboard?quizId=$quizId'
        : '/quiz/leaderboard';
    return _get(path);
  }
}

// Global singleton
final api = ApiClient();
