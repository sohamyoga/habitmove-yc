// ─── User ─────────────────────────────────────────────────────────────────────

class UserModel {
  final int id;
  final String name;
  final String email;
  final int role;
  final double walletBalance;
  final String? membershipValidityTo;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.walletBalance,
    this.membershipValidityTo,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id'] ?? 0,
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    role: j['role'] ?? 1,
    walletBalance: (j['wallet_balance'] ?? 0).toDouble(),
    membershipValidityTo: j['membership_validity_to'],
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get firstName => name.split(' ').first;
}

// ─── Course ───────────────────────────────────────────────────────────────────

class CourseModel {
  final int id;
  final String title;
  final String slug;
  final String? plan;
  final double? price;
  final double? discountedPrice;
  final String? banner;
  final String? shortDescription;
  final String? description;
  final CategoryModel? category;
  // enrolled-only fields
  final double? progress;
  final int? totalSessions;
  final int? completedSessions;

  const CourseModel({
    required this.id,
    required this.title,
    required this.slug,
    this.plan,
    this.price,
    this.discountedPrice,
    this.banner,
    this.shortDescription,
    this.description,
    this.category,
    this.progress,
    this.totalSessions,
    this.completedSessions,
  });

  factory CourseModel.fromJson(Map<String, dynamic> j) => CourseModel(
    id: j['id'] ?? 0,
    title: j['title'] ?? '',
    slug: j['slug'] ?? '${j['id']}',
    plan: j['plan'],
    price: j['price'] != null ? (j['price'] as num).toDouble() : null,
    discountedPrice: j['discounted_price'] != null ? (j['discounted_price'] as num).toDouble() : null,
    banner: j['banner'],
    shortDescription: j['short_description'],
    description: j['description'],
    category: j['category'] != null ? CategoryModel.fromJson(j['category']) : null,
    progress: j['progress'] != null ? (j['progress'] as num).toDouble() : null,
    totalSessions: j['total_sessions'],
    completedSessions: j['completed_sessions'],
  );

  bool get isFree => price == null || price == 0;
  bool get hasDiscount => discountedPrice != null && discountedPrice! < (price ?? 0);
  double get finalPrice => hasDiscount ? discountedPrice! : (price ?? 0);
  int get discountPercent => hasDiscount
      ? ((1 - discountedPrice! / price!) * 100).round()
      : 0;
}

// ─── Category ─────────────────────────────────────────────────────────────────

class CategoryModel {
  final int id;
  final String name;
  const CategoryModel({required this.id, required this.name});
  factory CategoryModel.fromJson(Map<String, dynamic> j) =>
      CategoryModel(id: j['id'] ?? 0, name: j['name'] ?? '');
}

// ─── Review ───────────────────────────────────────────────────────────────────

class ReviewModel {
  final String name;
  final String? email;
  final int rating;
  final String review;
  const ReviewModel({required this.name, this.email, required this.rating, required this.review});
  factory ReviewModel.fromJson(Map<String, dynamic> j) => ReviewModel(
    name: j['name'] ?? 'Anonymous',
    email: j['email'],
    rating: j['rating'] ?? 0,
    review: j['review'] ?? '',
  );
}

// ─── Coupon ───────────────────────────────────────────────────────────────────

class CouponModel {
  final bool valid;
  final String code;
  final String type; // percentage | fixed
  final double value;
  final String message;
  const CouponModel({required this.valid, required this.code, required this.type, required this.value, required this.message});
  factory CouponModel.fromJson(Map<String, dynamic> j) => CouponModel(
    valid: j['valid'] ?? false,
    code: j['code'] ?? '',
    type: j['type'] ?? 'percentage',
    value: (j['value'] ?? 0).toDouble(),
    message: j['message'] ?? '',
  );
}

// ─── Certificate ──────────────────────────────────────────────────────────────

class CertificateModel {
  final int id;
  final String courseTitle;
  final String? certificateUrl;
  final String? issuedAt;
  const CertificateModel({required this.id, required this.courseTitle, this.certificateUrl, this.issuedAt});
  factory CertificateModel.fromJson(Map<String, dynamic> j) => CertificateModel(
    id: j['id'] ?? 0,
    courseTitle: j['course']?['title'] ?? j['course_title'] ?? 'Course',
    certificateUrl: j['certificate_url'],
    issuedAt: j['created_at'],
  );
}

// ─── Quiz ─────────────────────────────────────────────────────────────────────

class QuizModel {
  final int id;
  final String title;
  final String? description;
  final int? totalQuestions;
  const QuizModel({required this.id, required this.title, this.description, this.totalQuestions});
  factory QuizModel.fromJson(Map<String, dynamic> j) => QuizModel(
    id: j['id'] ?? 0,
    title: j['title'] ?? '',
    description: j['description'],
    totalQuestions: j['total_questions'] ?? j['questions_count'],
  );
}

class QuizQuestion {
  final int id;
  final String question;
  final String type; // multiple_choice | multiple_response | short_answer
  final List<QuizOption> options;
  const QuizQuestion({required this.id, required this.question, required this.type, required this.options});
  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: j['id'] ?? 0,
    question: j['question'] ?? '',
    type: j['type'] ?? 'multiple_choice',
    options: (j['options'] as List? ?? []).map((o) => QuizOption.fromJson(o)).toList(),
  );
}

class QuizOption {
  final int id;
  final String text;
  const QuizOption({required this.id, required this.text});
  factory QuizOption.fromJson(Map<String, dynamic> j) => QuizOption(
    id: j['id'] ?? 0,
    text: j['text'] ?? j['option'] ?? '',
  );
}

class QuizResult {
  final int score;
  final int total;
  final double percentage;
  final bool passed;
  const QuizResult({required this.score, required this.total, required this.percentage, required this.passed});
  factory QuizResult.fromJson(Map<String, dynamic> j) {
    final score = j['score'] ?? j['correct'] ?? 0;
    final total = j['total'] ?? j['total_questions'] ?? 1;
    final pct = j['percentage'] ?? (score / total * 100);
    return QuizResult(
      score: score, total: total,
      percentage: (pct as num).toDouble(),
      passed: j['passed'] ?? pct >= 70,
    );
  }
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

class DashboardModel {
  final int activeCourses;
  final int completedCourses;
  final int totalCertificates;
  final List<CourseModel> recentLearning;
  const DashboardModel({
    required this.activeCourses,
    required this.completedCourses,
    required this.totalCertificates,
    required this.recentLearning,
  });
  factory DashboardModel.fromJson(Map<String, dynamic> j) => DashboardModel(
    activeCourses: j['active_courses'] ?? 0,
    completedCourses: j['completed_courses'] ?? 0,
    totalCertificates: j['total_certificates'] ?? 0,
    recentLearning: (j['recent_learning'] as List? ?? [])
        .map((c) => CourseModel.fromJson(c)).toList(),
  );
}
