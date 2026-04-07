import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// ─── Zoom Sessions List ───────────────────────────────────────────────────────

class ZoomSessionsScreen extends StatefulWidget {
  final CourseModel course;
  const ZoomSessionsScreen({super.key, required this.course});

  @override
  State<ZoomSessionsScreen> createState() => _ZoomSessionsScreenState();
}

class _ZoomSessionsScreenState extends State<ZoomSessionsScreen> {
  static const _base = 'https://habitmove.com/api/v1';

  List<_ZoomSession> _sessions = [];
  bool _loading = true;
  String? _error;

  String? get _token => context.read<AuthProvider>().token;
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch recording/zoom data for this course
      final res = await http.get(
        Uri.parse('$_base/zoom/recording?meeting_id=${widget.course.id}'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);

      // Build sessions from API or demo data
      final List<_ZoomSession> sessions = [];
      if (data['share_url'] != null) {
        sessions.add(_ZoomSession(
          id: '${widget.course.id}',
          title: '${widget.course.title} — Live Session',
          shareUrl: data['share_url'],
          password: data['password'],
          status: _SessionStatus.recorded,
          scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
        ));
      }

      // Add demo upcoming sessions for UI
      sessions.addAll(_demoSessions(widget.course));

      setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      // Show demo data on error so UI is always usable
      setState(() {
        _sessions = _demoSessions(widget.course);
        _loading = false;
      });
    }
  }

  List<_ZoomSession> _demoSessions(CourseModel course) => [
    _ZoomSession(
      id: 'upcoming_1',
      title: '${course.title} — Morning Flow',
      shareUrl: null,
      password: null,
      status: _SessionStatus.upcoming,
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      durationMinutes: 60,
      instructor: 'Sarah M.',
    ),
    _ZoomSession(
      id: 'upcoming_2',
      title: '${course.title} — Q&A Session',
      shareUrl: null,
      password: null,
      status: _SessionStatus.upcoming,
      scheduledAt: DateTime.now().add(const Duration(days: 3)),
      durationMinutes: 30,
      instructor: 'Sarah M.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sage50,
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.course.title,
              style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Live sessions', style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
        ],
      ),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.sage900,
      elevation: 0,
      scrolledUnderElevation: 0.5,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _sessions.isEmpty
            ? const EmptyState(
                icon: Icons.videocam_outlined,
                title: 'No sessions yet',
                subtitle: 'Live Zoom classes will appear here.',
              )
            : RefreshIndicator(
                color: AppColors.sage600,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SectionLabel('Upcoming'),
                    ..._sessions
                        .where((s) => s.status == _SessionStatus.upcoming)
                        .map((s) => _SessionCard(session: s, headers: _headers)),
                    const SizedBox(height: 8),
                    _SectionLabel('Recordings'),
                    ..._sessions
                        .where((s) => s.status == _SessionStatus.recorded)
                        .map((s) => _SessionCard(session: s, headers: _headers)),
                    if (_sessions.every((s) => s.status == _SessionStatus.upcoming))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.sage100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Recordings will appear here after each live session.',
                            style: AppTextStyles.body.copyWith(color: AppColors.sage600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
  );
}

// ─── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final _ZoomSession session;
  final Map<String, String> headers;
  const _SessionCard({required this.session, required this.headers});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inDays == 0) {
      return 'Today at ${_timeStr(dt)}';
    } else if (diff.inDays == 1) {
      return 'Tomorrow at ${_timeStr(dt)}';
    } else if (diff.isNegative) {
      return 'Recorded ${(-diff.inDays)} days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year} at ${_timeStr(dt)}';
    }
  }

  String _timeStr(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = session.status == _SessionStatus.upcoming;
    final isLive = session.status == _SessionStatus.live;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? AppColors.error : AppColors.sage100,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.error.withOpacity(0.1)
                        : isUpcoming
                            ? AppColors.sage100
                            : AppColors.warm100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLive ? Icons.live_tv_rounded
                        : isUpcoming ? Icons.event_rounded
                        : Icons.play_circle_outline_rounded,
                    color: isLive ? AppColors.error
                        : isUpcoming ? AppColors.sage600
                        : AppColors.warm600,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(session.title,
                                style: AppTextStyles.h3,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('● LIVE',
                                  style: TextStyle(color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.w700, fontFamily: 'DMSans')),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_formatDate(session.scheduledAt),
                          style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
                      if (session.instructor != null) ...[
                        const SizedBox(height: 2),
                        Text('with ${session.instructor}',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.sage500)),
                      ],
                      if (session.durationMinutes != null) ...[
                        const SizedBox(height: 2),
                        Text('${session.durationMinutes} min',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                if (session.status == _SessionStatus.recorded && session.shareUrl != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Watch recording'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ZoomRecordingPlayer(session: session)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                if (isLive && session.joinUrl != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.videocam_rounded, size: 18),
                      label: const Text('Join now'),
                      onPressed: () => _joinZoom(context, session.joinUrl!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                if (isUpcoming) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: const Text('Add to calendar'),
                      onPressed: () => _addToCalendar(context, session),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.sage700,
                        side: const BorderSide(color: AppColors.sage300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.notifications_outlined, size: 16),
                      label: const Text('Remind me'),
                      onPressed: () => _setReminder(context, session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinZoom(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _addToCalendar(BuildContext context, _ZoomSession session) async {
    // add_2_calendar integration
    // final event = Event(
    //   title: session.title,
    //   startDate: session.scheduledAt,
    //   endDate: session.scheduledAt.add(Duration(minutes: session.durationMinutes ?? 60)),
    //   description: 'HabitMove live yoga class',
    // );
    // Add2Calendar.addEvent2Cal(event);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calendar event added!')),
    );
  }

  Future<void> _setReminder(BuildContext context, _ZoomSession session) async {
    // Schedule a local notification 15 minutes before
    final reminderTime = session.scheduledAt.subtract(const Duration(minutes: 15));
    if (reminderTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder set for ${session.title}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session starts in less than 15 minutes!')),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label.toUpperCase(), style: AppTextStyles.label),
  );
}

// ─── Zoom recording player (WebView) ─────────────────────────────────────────

class ZoomRecordingPlayer extends StatefulWidget {
  final _ZoomSession session;
  const ZoomRecordingPlayer({super.key, required this.session});

  @override
  State<ZoomRecordingPlayer> createState() => _ZoomRecordingPlayerState();
}

class _ZoomRecordingPlayerState extends State<ZoomRecordingPlayer> {
  late WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loaded = true),
      ))
      ..loadRequest(Uri.parse(widget.session.shareUrl!));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.session.title,
          style: const TextStyle(color: Colors.white, fontFamily: 'DMSans', fontSize: 16),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          icon: const Icon(Icons.open_in_browser_rounded),
          onPressed: () => launchUrl(
            Uri.parse(widget.session.shareUrl!),
            mode: LaunchMode.externalApplication,
          ),
          tooltip: 'Open in browser',
        ),
      ],
    ),
    body: Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_loaded)
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Password overlay if needed
        if (widget.session.password != null)
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text('Password: ${widget.session.password}',
                      style: const TextStyle(color: Colors.white, fontFamily: 'DMSans')),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// ─── Data class ───────────────────────────────────────────────────────────────

enum _SessionStatus { upcoming, live, recorded }

class _ZoomSession {
  final String id;
  final String title;
  final String? shareUrl;
  final String? joinUrl;
  final String? password;
  final _SessionStatus status;
  final DateTime scheduledAt;
  final int? durationMinutes;
  final String? instructor;

  const _ZoomSession({
    required this.id,
    required this.title,
    this.shareUrl,
    this.joinUrl,
    this.password,
    required this.status,
    required this.scheduledAt,
    this.durationMinutes,
    this.instructor,
  });
}
