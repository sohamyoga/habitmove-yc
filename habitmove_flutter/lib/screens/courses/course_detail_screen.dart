import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../discussion/discussion_screen.dart';
import '../zoom/zoom_classes_screen.dart';
import '../offline/offline_screen.dart';
import '../zoom/zoom_sessions_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await api.getCourse(widget.course.slug);
      setState(() { _detail = d; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  CourseModel get course => widget.course;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.sage800,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              OfflineSaveButton(course: course),
              IconButton(
                icon: const Icon(Icons.videocam_outlined, color: Colors.white),
                tooltip: 'Live classes',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ZoomClassesScreen(course: course)),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: CourseImage(url: course.banner, title: course.title, height: 240),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.sage800,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.sage50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(course.title,
                              style: AppTextStyles.displaySm.copyWith(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        PriceWidget(price: course.price, discountedPrice: course.discountedPrice),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (course.plan != null) AppBadge(label: course.plan!),
                        if (course.hasDiscount) ...[
                          const SizedBox(width: 8),
                          AppBadge(label: '${course.discountPercent}% off', color: AppColors.warm500),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabs,
                      tabs: const [Tab(text: 'About'), Tab(text: 'Reviews'), Tab(text: 'Enroll'), Tab(text: 'Chat'), Tab(text: 'Live')],
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.sage800,
                      unselectedLabelColor: AppColors.grey400,
                      indicatorColor: AppColors.sage700,
                      indicatorWeight: 2,
                      labelStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorRetry(message: _error!, onRetry: _load)
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _AboutTab(detail: _detail!),
                      _ReviewsTab(reviews: (_detail!['reviews'] as List? ?? [])
                          .map((r) => ReviewModel.fromJson(r)).toList()),
                      _EnrollTab(course: course, detail: _detail!),
                      DiscussionScreen(course: course),
                      ZoomSessionsScreen(course: course),
                    ],
                  ),
      ),
    );
  }
}

// ─── About Tab ────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final Map<String, dynamic> detail;
  const _AboutTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    final course = detail['course'] as Map<String, dynamic>? ?? {};
    final offers = detail['offers'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (course['description'] != null)
            Text(course['description'], style: AppTextStyles.bodyLg),
          if (offers.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text("What's included", style: AppTextStyles.h2),
            const SizedBox(height: 12),
            ...offers.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.sage500, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(o['title'] ?? o['name'] ?? '$o',
                      style: AppTextStyles.body)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ─── Reviews Tab ─────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  final List<ReviewModel> reviews;
  const _ReviewsTab({required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const EmptyState(
      icon: Icons.rate_review_outlined,
      title: 'No reviews yet',
      subtitle: 'Be the first to leave a review.',
    );
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (_, i) {
        final r = reviews[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(initials: r.name.isNotEmpty ? r.name[0].toUpperCase() : '?', size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.name, style: AppTextStyles.h3),
                      const Spacer(),
                      StarRating(rating: r.rating),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.review, style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Enroll Tab ───────────────────────────────────────────────────────────────

class _EnrollTab extends StatefulWidget {
  final CourseModel course;
  final Map<String, dynamic> detail;
  const _EnrollTab({required this.course, required this.detail});
  @override
  State<_EnrollTab> createState() => _EnrollTabState();
}

class _EnrollTabState extends State<_EnrollTab> {
  final _couponCtrl = TextEditingController();
  CouponModel? _coupon;
  String? _couponErr;
  bool _checkingCoupon = false;
  String _paymentMethod = 'stripe';
  bool _enrolling = false;
  String? _enrollErr;
  bool _enrolled = false;

  @override
  void dispose() { _couponCtrl.dispose(); super.dispose(); }

  double get _finalPrice {
    double base = widget.course.finalPrice;
    if (_coupon == null) return base;
    if (_coupon!.type == 'percentage') return base * (1 - _coupon!.value / 100);
    return (base - _coupon!.value).clamp(0, double.infinity);
  }

  Future<void> _checkCoupon() async {
    setState(() { _couponErr = null; _checkingCoupon = true; });
    try {
      final c = await api.checkCoupon(widget.course.id, _couponCtrl.text.trim());
      setState(() { _coupon = c.valid ? c : null; _couponErr = c.valid ? null : c.message; });
    } on ApiException catch (e) {
      setState(() => _couponErr = e.message);
    } finally {
      setState(() => _checkingCoupon = false);
    }
  }

  Future<void> _enroll() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() => _enrollErr = 'Please sign in to enroll.');
      return;
    }
    setState(() { _enrolling = true; _enrollErr = null; });
    try {
      final result = await api.enrollCourse(
        name: auth.user!.name,
        email: auth.user!.email,
        courseId: widget.course.id,
        paymentMethod: _paymentMethod,
        couponCode: _coupon?.code,
      );
      final link = result['payment_links']?[_paymentMethod];
      if (link != null) {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      } else {
        setState(() => _enrolled = true);
      }
    } on ApiException catch (e) {
      setState(() => _enrollErr = e.message);
    } finally {
      setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (_enrolled) return _EnrolledSuccess();
    if (!auth.isAuthenticated) return _SignInPrompt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_enrollErr != null) ...[
            AlertBanner(message: _enrollErr!),
            const SizedBox(height: 16),
          ],

          if (!widget.course.isFree) ...[
            // Coupon
            Text('Coupon code', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'e.g. SAVE10',
                      hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.sage200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.sage200)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _checkingCoupon ? null : _checkCoupon,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _checkingCoupon
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Apply'),
                ),
              ],
            ),
            if (_couponErr != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_couponErr!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
              ),
            if (_coupon != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(_coupon!.message, style: AppTextStyles.bodySm.copyWith(color: AppColors.success)),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Payment method
            Text('Payment method', style: AppTextStyles.h3),
            const SizedBox(height: 10),
            Row(
              children: ['stripe', 'paypal'].map((m) {
                final selected = _paymentMethod == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentMethod = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: m == 'stripe' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.sage50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.sage600 : AppColors.sage200,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        m == 'stripe' ? '💳  Card' : '🅿️  PayPal',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? AppColors.sage800 : AppColors.grey600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sage50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sage100),
            ),
            child: Column(
              children: [
                _SummaryRow('Course', widget.course.title, isTitle: true),
                if (!widget.course.isFree) ...[
                  const SizedBox(height: 8),
                  _SummaryRow('Price', '£${widget.course.finalPrice.toStringAsFixed(2)}'),
                  if (_coupon != null) _SummaryRow('Discount', 'Applied ✓', highlight: true),
                  const Divider(height: 20),
                  _SummaryRow(
                    'Total',
                    '£${_finalPrice.toStringAsFixed(2)}',
                    bold: true,
                  ),
                ],
                if (widget.course.isFree) ...[
                  const Divider(height: 20),
                  _SummaryRow('Total', 'Free', bold: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          PrimaryButton(
            label: widget.course.isFree
                ? 'Enroll for free'
                : 'Pay £${_finalPrice.toStringAsFixed(2)}',
            loading: _enrolling,
            onPressed: _enroll,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool isTitle;
  final bool highlight;
  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.isTitle = false, this.highlight = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: AppTextStyles.body.copyWith(
          color: AppColors.grey600, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
      const Spacer(),
      Text(
        value,
        style: AppTextStyles.body.copyWith(
          color: highlight ? AppColors.success : (bold ? AppColors.sage900 : AppColors.sage700),
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _EnrolledSuccess extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.sage100, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.sage600, size: 44),
          ),
          const SizedBox(height: 20),
          const Text("You're enrolled!", style: TextStyle(
            fontFamily: 'DMSerifDisplay', fontSize: 28, color: AppColors.sage900)),
          const SizedBox(height: 8),
          const Text('Check your email for access details.',
              style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SecondaryButton(
            label: 'Back to courses',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.sage300, size: 52),
          const SizedBox(height: 16),
          const Text('Sign in to enroll', style: AppTextStyles.displaySm),
          const SizedBox(height: 8),
          const Text('Create a free account to start this course.',
              style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Sign in',
            onPressed: () => Navigator.pushNamed(context, '/auth'),
          ),
        ],
      ),
    ),
  );
}
