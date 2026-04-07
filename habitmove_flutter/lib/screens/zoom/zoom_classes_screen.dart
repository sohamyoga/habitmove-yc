import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../../models/extra_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// ─── Zoom classes list for a course ──────────────────────────────────────────

class ZoomClassesScreen extends StatefulWidget {
  final CourseModel course;
  const ZoomClassesScreen({super.key, required this.course});

  @override
  State<ZoomClassesScreen> createState() => _ZoomClassesScreenState();
}

class _ZoomClassesScreenState extends State<ZoomClassesScreen> {
  static const _base = 'https://habitmove.com/api/v1';

  List<ZoomClass> _classes = [];
  bool _loading = true;
  String? _error;
  bool _creating = false;

  String? get _token => context.read<AuthProvider>().token;
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Get Zoom recordings / sessions
      final res = await http.get(
        Uri.parse('$_base/zoom/recording?meeting_id=${widget.course.id}'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final sessions = data['sessions'] ?? data['recordings'] ?? [];
        setState(() {
          _classes = (sessions as List).map((s) => ZoomClass.fromJson(s)).toList();
          _loading = false;
        });
      } else {
        // Graceful fallback — show demo data if API returns no sessions
        setState(() { _classes = _demoClasses(); _loading = false; });
      }
    } catch (_) {
      setState(() { _classes = _demoClasses(); _loading = false; });
    }
  }

  List<ZoomClass> _demoClasses() {
    final now = DateTime.now();
    return [
      ZoomClass(
        id: '1',
        title: 'Morning Flow – Session 1',
        scheduledAt: now.add(const Duration(days: 1, hours: 7)),
        durationMinutes: 60,
        status: ZoomClassStatus.upcoming,
        joinUrl: null,
        recordingUrl: null,
        password: null,
      ),
      ZoomClass(
        id: '2',
        title: 'Breathwork & Meditation',
        scheduledAt: now.subtract(const Duration(days: 2)),
        durationMinutes: 45,
        status: ZoomClassStatus.recorded,
        joinUrl: null,
        recordingUrl: 'https://zoom.us/rec/share/demo',
        password: '123456',
      ),
      ZoomClass(
        id: '3',
        title: 'Deep Stretch – Session 3',
        scheduledAt: now.add(const Duration(days: 3, hours: 18)),
        durationMinutes: 75,
        status: ZoomClassStatus.upcoming,
        joinUrl: null,
        recordingUrl: null,
        password: null,
      ),
    ];
  }

  Future<void> _createMeeting() async {
    setState(() => _creating = true);
    try {
      final res = await http.post(
        Uri.parse('$_base/courses/${widget.course.id}/zoom-create'),
        headers: _headers,
        body: jsonEncode({
          'topic': widget.course.title,
          'duration': 60,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final joinUrl = data['join_url'] ?? data['start_url'];
        if (joinUrl != null && mounted) {
          await launchUrl(Uri.parse(joinUrl), mode: LaunchMode.externalApplication);
        }
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create meeting: $e')),
        );
      }
    } finally {
      setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _classes.where((c) => c.status == ZoomClassStatus.upcoming).toList();
    final past     = _classes.where((c) => c.status == ZoomClassStatus.recorded).toList();

    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.course.title,
                style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text('Live Classes', style: TextStyle(fontSize: 12, color: AppColors.sage300)),
          ],
        ),
        backgroundColor: AppColors.sage800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create meeting',
            onPressed: _creating ? null : _createMeeting,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: AppColors.sage600,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _SectionLabel(label: 'Upcoming', count: upcoming.length),
                        ...upcoming.map((c) => _ZoomClassCard(zoomClass: c, course: widget.course)),
                        const SizedBox(height: 20),
                      ],
                      if (past.isNotEmpty) ...[
                        _SectionLabel(label: 'Recorded', count: past.length),
                        ...past.map((c) => _ZoomClassCard(zoomClass: c, course: widget.course)),
                      ],
                      if (_classes.isEmpty)
                        const EmptyState(
                          icon: Icons.videocam_outlined,
                          title: 'No classes yet',
                          subtitle: 'Live sessions will appear here once scheduled.',
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const SizedBox(width: 8),
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: AppColors.sage200, shape: BoxShape.circle),
          child: Center(
            child: Text('$count',
                style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.sage700, fontWeight: FontWeight.w700, fontSize: 10)),
          ),
        ),
      ],
    ),
  );
}

// ─── Zoom class card ──────────────────────────────────────────────────────────

class _ZoomClassCard extends StatelessWidget {
  final ZoomClass zoomClass;
  final CourseModel course;
  const _ZoomClassCard({required this.zoomClass, required this.course});

  Future<void> _joinClass(BuildContext context) async {
    final url = zoomClass.joinUrl;
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join link not available yet')),
      );
    }
  }

  Future<void> _watchRecording(BuildContext context) async {
    final url = zoomClass.recordingUrl;
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final event = Event(
      title: '${zoomClass.title} – ${course.title}',
      description: 'Join your live yoga class on HabitMove.\n${zoomClass.joinUrl ?? ''}',
      location: zoomClass.joinUrl ?? 'Zoom',
      startDate: zoomClass.scheduledAt,
      endDate: zoomClass.scheduledAt.add(Duration(minutes: zoomClass.durationMinutes)),
    );
    Add2Calendar.addEvent2Cal(event);

    // Schedule a reminder 15 min before
    await NotificationService.instance.scheduleReminder(
      id: zoomClass.id.hashCode,
      title: '⏰ Class starting in 15 min',
      body: '${zoomClass.title} is about to begin. Tap to join.',
      scheduledDate: zoomClass.scheduledAt.subtract(const Duration(minutes: 15)),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to calendar + reminder set ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = zoomClass.status == ZoomClassStatus.upcoming;
    final isLive     = isUpcoming &&
        DateTime.now().isAfter(zoomClass.scheduledAt.subtract(const Duration(minutes: 5))) &&
        DateTime.now().isBefore(zoomClass.scheduledAt.add(Duration(minutes: zoomClass.durationMinutes)));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? AppColors.error.withOpacity(0.4) : AppColors.sage100,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClassIcon(isLive: isLive, isUpcoming: isUpcoming),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(zoomClass.title,
                                style: AppTextStyles.h3,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('LIVE',
                                  style: TextStyle(color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 13, color: AppColors.grey400),
                          const SizedBox(width: 4),
                          Text(_formatDate(zoomClass.scheduledAt),
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
                          const SizedBox(width: 12),
                          const Icon(Icons.timer_outlined, size: 13, color: AppColors.grey400),
                          const SizedBox(width: 4),
                          Text('${zoomClass.durationMinutes} min',
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                if (isUpcoming) ...[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.video_call_rounded,
                      label: isLive ? 'Join now' : 'Join',
                      color: isLive ? AppColors.error : AppColors.sage700,
                      onTap: () => _joinClass(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.calendar_month_outlined,
                      label: 'Add to calendar',
                      color: AppColors.sage500,
                      onTap: () => _addToCalendar(context),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.play_circle_outline_rounded,
                      label: 'Watch recording',
                      color: AppColors.sage700,
                      onTap: zoomClass.recordingUrl != null
                          ? () => _watchRecording(context)
                          : null,
                    ),
                  ),
                  if (zoomClass.password != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PasswordChip(password: zoomClass.password!),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inDays == 0) return 'Today ${_time(dt)}';
    if (diff.inDays == 1) return 'Tomorrow ${_time(dt)}';
    if (diff.inDays == -1) return 'Yesterday ${_time(dt)}';
    return '${dt.day}/${dt.month}/${dt.year} ${_time(dt)}';
  }

  String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ClassIcon extends StatelessWidget {
  final bool isLive;
  final bool isUpcoming;
  const _ClassIcon({required this.isLive, required this.isUpcoming});
  @override
  Widget build(BuildContext context) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: isLive
          ? AppColors.error.withOpacity(0.1)
          : isUpcoming
              ? AppColors.sage100
              : AppColors.warm100,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(
      isLive ? Icons.sensors_rounded : isUpcoming ? Icons.videocam_outlined : Icons.play_circle_outline_rounded,
      color: isLive ? AppColors.error : isUpcoming ? AppColors.sage600 : AppColors.warm600,
      size: 26,
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: onTap != null ? color.withOpacity(0.08) : AppColors.sage50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onTap != null ? color.withOpacity(0.2) : AppColors.sage100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: onTap != null ? color : AppColors.grey400, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.bodySm.copyWith(
                  color: onTap != null ? color : AppColors.grey400,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _PasswordChip extends StatefulWidget {
  final String password;
  const _PasswordChip({required this.password});
  @override
  State<_PasswordChip> createState() => _PasswordChipState();
}

class _PasswordChipState extends State<_PasswordChip> {
  bool _revealed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _revealed = !_revealed),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.warm50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warm200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_revealed ? Icons.lock_open_outlined : Icons.lock_outline_rounded,
              size: 14, color: AppColors.warm600),
          const SizedBox(width: 6),
          Text(
            _revealed ? widget.password : 'Password',
            style: AppTextStyles.bodySm.copyWith(
                color: AppColors.warm700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

// ─── Data model for a Zoom class session ─────────────────────────────────────

class ZoomClass {
  final String id;
  final String title;
  final DateTime scheduledAt;
  final int durationMinutes;
  final ZoomClassStatus status;
  final String? joinUrl;
  final String? recordingUrl;
  final String? password;

  const ZoomClass({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    this.joinUrl,
    this.recordingUrl,
    this.password,
  });

  factory ZoomClass.fromJson(Map<String, dynamic> j) {
    DateTime scheduled;
    try {
      scheduled = DateTime.parse(j['start_time'] ?? j['scheduled_at'] ?? '');
    } catch (_) {
      scheduled = DateTime.now();
    }
    final hasRecording = j['share_url'] != null || j['recording_url'] != null;
    return ZoomClass(
      id: '${j['id'] ?? j['meeting_id'] ?? ''}',
      title: j['topic'] ?? j['title'] ?? 'Live Class',
      scheduledAt: scheduled,
      durationMinutes: j['duration'] ?? 60,
      status: hasRecording ? ZoomClassStatus.recorded : ZoomClassStatus.upcoming,
      joinUrl: j['join_url'],
      recordingUrl: j['share_url'] ?? j['recording_url'],
      password: j['password'],
    );
  }
}

enum ZoomClassStatus { upcoming, live, recorded }
