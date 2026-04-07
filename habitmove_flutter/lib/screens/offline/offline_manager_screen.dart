import 'package:flutter/material.dart';
import '../../services/offline_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class OfflineManagerScreen extends StatefulWidget {
  const OfflineManagerScreen({super.key});

  @override
  State<OfflineManagerScreen> createState() => _OfflineManagerScreenState();
}

class _OfflineManagerScreenState extends State<OfflineManagerScreen> {
  bool _clearing = false;
  late Map<String, dynamic> _stats;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _stats = OfflineCacheService.instance.stats);

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear cache?',
            style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22)),
        content: const Text(
            'All locally stored course and quiz data will be removed. '
            'You\'ll need to be online to reload content.',
            style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _clearing = true);
    await OfflineCacheService.instance.clearAll();
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() { _clearing = false; _refresh(); });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _stats['online'] as bool;

    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: const Text('Offline & Storage'),
        backgroundColor: AppColors.sage800,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
            fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: AppColors.sage600,
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Connection status card
            _StatusCard(online: online),
            const SizedBox(height: 20),

            // What's cached
            Text('Cached data', style: AppTextStyles.label),
            const SizedBox(height: 10),
            _CacheRow(
              icon: Icons.school_outlined,
              label: 'Courses',
              count: _stats['courses_cached'],
              color: AppColors.sage600,
            ),
            _CacheRow(
              icon: Icons.bookmark_outline_rounded,
              label: 'My courses',
              count: _stats['my_courses_cached'],
              color: AppColors.warm600,
            ),
            _CacheRow(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              count: _stats['dashboard_cached'],
              color: AppColors.sage500,
            ),
            _CacheRow(
              icon: Icons.quiz_outlined,
              label: 'Quizzes',
              count: _stats['quizzes_cached'],
              color: AppColors.warm500,
            ),
            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.sage100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.sage600),
                    const SizedBox(width: 8),
                    Text('How offline mode works', style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600, color: AppColors.sage700)),
                  ]),
                  const SizedBox(height: 8),
                  ...[
                    'Course lists and details are cached for up to 60 minutes.',
                    'Your enrolled courses and quiz list are saved when you\'re online.',
                    'Discussion messages, payments and quiz submissions require a connection.',
                    'Data refreshes automatically when you reconnect.',
                  ].map((t) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppColors.sage500)),
                        Expanded(child: Text(t, style: AppTextStyles.bodySm)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Clear button
            _clearing
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Clear all cached data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool online;
  const _StatusCard({required this.online});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: online ? AppColors.sage800 : AppColors.warm600,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                online ? 'Connected' : 'Offline',
                style: const TextStyle(
                    fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                online
                    ? 'Content syncs in real time'
                    : 'Showing last cached content',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'DMSans'),
              ),
            ],
          ),
        ),
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? const Color(0xFF4ADE80) : Colors.white54,
          ),
        ),
      ],
    ),
  );
}

class _CacheRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _CacheRow({required this.icon, required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.sage100),
    ),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.sage100 : AppColors.grey50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count > 0 ? 'Cached' : 'Not cached',
            style: AppTextStyles.bodySm.copyWith(
              color: count > 0 ? AppColors.sage700 : AppColors.grey400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
