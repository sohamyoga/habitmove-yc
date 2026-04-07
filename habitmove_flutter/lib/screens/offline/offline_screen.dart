import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/offline_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../courses/course_detail_screen.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  List<CourseModel> _savedCourses = [];
  bool _loading = true;
  String _cacheSize = '…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await OfflineService.instance.getOfflineCourses();
    final size = await OfflineService.instance.cacheSizeString;
    setState(() {
      _savedCourses = raw.map((j) => CourseModel.fromJson(j)).toList();
      _cacheSize = size;
      _loading = false;
    });
  }

  Future<void> _remove(CourseModel course) async {
    await OfflineService.instance.removeOfflineCourse(course.id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${course.title} removed from offline')),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear all offline data?',
            style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22)),
        content: Text(
          'This will remove all saved courses and cached data ($_cacheSize). '
          'You will need to be online to reload them.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await OfflineService.instance.clearAll();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline data cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = OfflineService.instance.isOnline;

    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: const Text('Offline Library'),
        backgroundColor: AppColors.sage800,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
            fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
        actions: [
          if (_savedCourses.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Connectivity banner
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isOnline
                ? const SizedBox.shrink()
                : _OfflineBanner(),
          ),

          // Stats bar
          _StatsBar(
            courseCount: _savedCourses.length,
            cacheSize: _cacheSize,
          ),

          // Course list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _savedCourses.isEmpty
                    ? _EmptyOfflineState(isOnline: isOnline)
                    : RefreshIndicator(
                        color: AppColors.sage600,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _savedCourses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _OfflineCourseCard(
                            course: _savedCourses[i],
                            onRemove: () => _remove(_savedCourses[i]),
                            onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailScreen(course: _savedCourses[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Offline Banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('offline-banner'),
    width: double.infinity,
    color: const Color(0xFFEF4444),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'You\'re offline — showing saved content only',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

// ─── Stats Bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int courseCount;
  final String cacheSize;
  const _StatsBar({required this.courseCount, required this.cacheSize});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(
      children: [
        _Stat(label: 'Saved courses', value: '$courseCount'),
        Container(width: 1, height: 32, color: AppColors.sage100, margin: const EdgeInsets.symmetric(horizontal: 20)),
        _Stat(label: 'Cache size', value: cacheSize),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.sage100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                OfflineService.instance.isOnline
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                size: 13,
                color: OfflineService.instance.isOnline
                    ? AppColors.sage600
                    : AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                OfflineService.instance.isOnline ? 'Online' : 'Offline',
                style: AppTextStyles.bodySm.copyWith(
                  color: OfflineService.instance.isOnline
                      ? AppColors.sage600
                      : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: AppTextStyles.h2.copyWith(color: AppColors.sage800)),
      Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
    ],
  );
}

// ─── Course card ──────────────────────────────────────────────────────────────

class _OfflineCourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _OfflineCourseCard({
    required this.course,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Dismissible(
    key: Key('offline-course-${course.id}'),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => onRemove(),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
    ),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sage100),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72, height: 72,
                child: CourseImage(url: course.banner, title: course.title, height: 72),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      style: AppTextStyles.h3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.download_done_rounded,
                          size: 13, color: AppColors.sage500),
                      const SizedBox(width: 4),
                      Text('Available offline',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.sage500)),
                    ],
                  ),
                  if (course.plan != null) ...[
                    const SizedBox(height: 4),
                    AppBadge(label: course.plan!),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.grey400),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyOfflineState extends StatelessWidget {
  final bool isOnline;
  const _EmptyOfflineState({required this.isOnline});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: AppColors.sage100, shape: BoxShape.circle),
            child: const Icon(Icons.download_outlined,
                color: AppColors.sage300, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No offline courses',
              style: TextStyle(
                  fontFamily: 'DMSerifDisplay',
                  fontSize: 24,
                  color: AppColors.sage800)),
          const SizedBox(height: 8),
          Text(
            isOnline
                ? 'Open any course and tap the download icon to save it for offline access.'
                : 'Go online to browse and download courses.',
            style: AppTextStyles.body.copyWith(color: AppColors.grey400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ─── Offline save button widget (used in CourseDetail) ───────────────────────

class OfflineSaveButton extends StatefulWidget {
  final CourseModel course;
  const OfflineSaveButton({super.key, required this.course});

  @override
  State<OfflineSaveButton> createState() => _OfflineSaveButtonState();
}

class _OfflineSaveButtonState extends State<OfflineSaveButton> {
  bool _saved = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await OfflineService.instance.isCourseOffline(widget.course.id);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    if (_saved) {
      await OfflineService.instance.removeOfflineCourse(widget.course.id);
    } else {
      // Build a minimal JSON map from the model for offline storage
      await OfflineService.instance.saveForOffline({
        'id': widget.course.id,
        'title': widget.course.title,
        'slug': widget.course.slug,
        'plan': widget.course.plan,
        'price': widget.course.price,
        'discounted_price': widget.course.discountedPrice,
        'banner': widget.course.banner,
        'short_description': widget.course.shortDescription,
        'description': widget.course.description,
      });
    }
    await _checkSaved();
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_saved
            ? '${widget.course.title} saved for offline'
            : '${widget.course.title} removed'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sage600))
      : IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _saved ? Icons.download_done_rounded : Icons.download_outlined,
              key: ValueKey(_saved),
              color: _saved ? AppColors.sage600 : AppColors.grey400,
            ),
          ),
          tooltip: _saved ? 'Remove offline copy' : 'Save for offline',
          onPressed: _toggle,
        );
}
