// Add to models.dart — Discussion models

class DiscussionMessage {
  final int id;
  final int userId;
  final int courseId;
  final String? message;
  final String? filePath;
  final String? fileType;
  final String createdAt;
  final DiscussionUser user;

  const DiscussionMessage({
    required this.id,
    required this.userId,
    required this.courseId,
    this.message,
    this.filePath,
    this.fileType,
    required this.createdAt,
    required this.user,
  });

  factory DiscussionMessage.fromJson(Map<String, dynamic> j) => DiscussionMessage(
    id: j['id'] ?? 0,
    userId: j['user_id'] ?? 0,
    courseId: j['course_id'] ?? 0,
    message: j['message'],
    filePath: j['file_path'],
    fileType: j['file_type'],
    createdAt: j['created_at'] ?? DateTime.now().toIso8601String(),
    user: DiscussionUser.fromJson(j['user'] ?? {}),
  );

  bool get hasFile => filePath != null;
  bool get isImage => fileType?.startsWith('image/') ?? false;
}

class DiscussionUser {
  final int id;
  final String name;
  const DiscussionUser({required this.id, required this.name});

  factory DiscussionUser.fromJson(Map<String, dynamic> j) => DiscussionUser(
    id: j['id'] ?? 0,
    name: j['name'] ?? 'Unknown',
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Ticket / Support models ──────────────────────────────────────────────────

class TicketModel {
  final int id;
  final String subject;
  final String category;
  final String status;
  final String createdAt;
  final List<TicketReply> replies;

  const TicketModel({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.replies,
  });

  factory TicketModel.fromJson(Map<String, dynamic> j) => TicketModel(
    id: j['id'] ?? 0,
    subject: j['subject'] ?? '',
    category: j['category'] ?? '',
    status: j['status'] ?? 'open',
    createdAt: j['created_at'] ?? '',
    replies: (j['replies'] as List? ?? []).map((r) => TicketReply.fromJson(r)).toList(),
  );

  Color get statusColor {
    switch (status) {
      case 'open':        return const Color(0xFF3B82F6);
      case 'in_progress': return const Color(0xFFF59E0B);
      case 'resolved':    return const Color(0xFF16A34A);
      case 'closed':      return const Color(0xFF6B7280);
      default:            return const Color(0xFF6B7280);
    }
  }
}

class TicketReply {
  final int id;
  final String message;
  final String createdAt;
  final Map<String, dynamic>? user;
  const TicketReply({required this.id, required this.message, required this.createdAt, this.user});
  factory TicketReply.fromJson(Map<String, dynamic> j) => TicketReply(
    id: j['id'] ?? 0,
    message: j['message'] ?? '',
    createdAt: j['created_at'] ?? '',
    user: j['user'],
  );
}

// ─── Membership plan model ────────────────────────────────────────────────────

class MembershipPlan {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? interval; // monthly | yearly
  final List<String> features;
  final bool isPopular;

  const MembershipPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.interval,
    required this.features,
    this.isPopular = false,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> j) => MembershipPlan(
    id: j['id'] ?? 0,
    name: j['name'] ?? j['title'] ?? '',
    description: j['description'],
    price: (j['price'] ?? 0).toDouble(),
    interval: j['interval'] ?? j['period'],
    features: (j['features'] as List? ?? []).map((f) => '$f').toList(),
    isPopular: j['is_popular'] ?? false,
  );
}
