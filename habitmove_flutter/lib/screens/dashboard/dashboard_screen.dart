import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/offline_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardModel? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    // Try cache first if offline
    if (!OfflineCacheService.instance.isOnline) {
      final cached = OfflineCacheService.instance.getDashboard();
      if (cached != null) {
        setState(() { _data = DashboardModel.fromJson(cached); _loading = false; });
        return;
      }
    }

    try {
      final d = await api.getDashboard();
      // Save to cache
      await OfflineCacheService.instance.saveDashboard({
        'active_courses': d.activeCourses,
        'completed_courses': d.completedCourses,
        'total_certificates': d.totalCertificates,
        'recent_learning': d.recentLearning.map((c) => {
          'id': c.id, 'title': c.title, 'slug': c.slug,
          'banner': c.banner, 'progress': c.progress,
          'total_sessions': c.totalSessions,
          'completed_sessions': c.completedSessions,
        }).toList(),
      });
      setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      // Fall back to stale cache on error
      final cached = OfflineCacheService.instance.getDashboard();
      if (cached != null) {
        setState(() { _data = DashboardModel.fromJson(cached); _loading = false; });
      } else {
        setState(() { _error = e.message; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: RefreshIndicator(
        color: AppColors.sage600,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            _buildHeroSliver(user),
            const SliverToBoxAdapter(child: OfflineBanner()),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(child: ErrorRetry(message: _error!, onRetry: _load))
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSliver(UserModel? user) => SliverToBoxAdapter(
    child: Container(
      decoration: const BoxDecoration(color: AppColors.sage800),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24, right: 24, bottom: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning,',
                      style: AppTextStyles.body.copyWith(color: AppColors.sage300),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.firstName ?? 'Yogi',
                      style: const TextStyle(
                        fontFamily: 'DMSerifDisplay', fontSize: 28,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (user != null) UserAvatar(initials: user.initials, size: 44),
            ],
          ),
          if (_data != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                _StatChip(label: 'Active', value: '${_data!.activeCourses}'),
                const SizedBox(width: 10),
                _StatChip(label: 'Completed', value: '${_data!.completedCourses}'),
                const SizedBox(width: 10),
                _StatChip(label: 'Certificates', value: '${_data!.totalCertificates}'),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildContent() {
    final d = _data!;
    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Learning
              if (d.recentLearning.isNotEmpty) ...[
                const SectionTitle(title: 'Continue learning'),
                const SizedBox(height: 16),
                ...d.recentLearning.map((c) => _RecentCourseCard(course: c)),
                const SizedBox(height: 32),
              ],

              // Quick stats cards
              const SectionTitle(title: 'Your progress'),
              const SizedBox(height: 16),
              _ProgressOverview(data: d),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sage700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(
            fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.sage300)),
        ],
      ),
    ),
  );
}

class _RecentCourseCard extends StatelessWidget {
  final CourseModel course;
  const _RecentCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final progress = (course.progress ?? 0) / 100;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60, height: 60,
              child: CourseImage(url: course.banner, title: course.title, height: 60),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                LinearPercentIndicator(
                  lineHeight: 6,
                  percent: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.sage100,
                  progressColor: AppColors.sage500,
                  barRadius: const Radius.circular(4),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).round()}% complete',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressOverview extends StatelessWidget {
  final DashboardModel data;
  const _ProgressOverview({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.activeCourses + data.completedCourses;
    final completionRate = total > 0 ? data.completedCourses / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sage100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircularPercentIndicator(
                radius: 50,
                lineWidth: 8,
                percent: completionRate.clamp(0.0, 1.0),
                center: Text(
                  '${(completionRate * 100).round()}%',
                  style: AppTextStyles.h2.copyWith(color: AppColors.sage700),
                ),
                progressColor: AppColors.sage600,
                backgroundColor: AppColors.sage100,
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Completion rate', style: AppTextStyles.h3),
                    const SizedBox(height: 4),
                    Text(
                      '${data.completedCourses} of $total courses finished',
                      style: AppTextStyles.body.copyWith(color: AppColors.grey400),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Dot(color: AppColors.sage600), const SizedBox(width: 6),
                        Text('${data.completedCourses} done',
                            style: AppTextStyles.bodySm),
                        const SizedBox(width: 14),
                        _Dot(color: AppColors.sage200), const SizedBox(width: 6),
                        Text('${data.activeCourses} active',
                            style: AppTextStyles.bodySm),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
