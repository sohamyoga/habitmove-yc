import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _granted = false;
  bool _courseUpdates = true;
  bool _quizReminders = true;
  bool _discussionReplies = true;
  bool _membershipAlerts = true;
  bool _loading = true;

  static const _prefPrefix = 'notif_';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _courseUpdates      = prefs.getBool('${_prefPrefix}course') ?? true;
      _quizReminders      = prefs.getBool('${_prefPrefix}quiz') ?? true;
      _discussionReplies  = prefs.getBool('${_prefPrefix}discussion') ?? true;
      _membershipAlerts   = prefs.getBool('${_prefPrefix}membership') ?? true;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefPrefix}$key', value);
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.instance.requestPermission();
    setState(() => _granted = granted);
    if (granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications enabled ✓')),
      );
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.instance.notifyEnrollmentSuccess('Yoga for Beginners');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.sage800,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Permission banner
                if (!_granted)
                  _PermissionBanner(onEnable: _requestPermission),

                const _SectionHeader('Preferences'),

                _ToggleTile(
                  icon: Icons.school_outlined,
                  iconColor: AppColors.sage600,
                  title: 'Course updates',
                  subtitle: 'New sessions, instructor announcements',
                  value: _courseUpdates,
                  onChanged: (v) {
                    setState(() => _courseUpdates = v);
                    _save('course', v);
                  },
                ),
                _ToggleTile(
                  icon: Icons.quiz_outlined,
                  iconColor: AppColors.warm600,
                  title: 'Quiz reminders',
                  subtitle: 'Reminders before a quiz closes',
                  value: _quizReminders,
                  onChanged: (v) {
                    setState(() => _quizReminders = v);
                    _save('quiz', v);
                  },
                ),
                _ToggleTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: AppColors.sage500,
                  title: 'Discussion replies',
                  subtitle: 'When someone replies to your message',
                  value: _discussionReplies,
                  onChanged: (v) {
                    setState(() => _discussionReplies = v);
                    _save('discussion', v);
                  },
                ),
                _ToggleTile(
                  icon: Icons.card_membership_outlined,
                  iconColor: AppColors.warm500,
                  title: 'Membership alerts',
                  subtitle: 'Expiry reminders and renewal offers',
                  value: _membershipAlerts,
                  onChanged: (v) {
                    setState(() => _membershipAlerts = v);
                    _save('membership', v);
                  },
                ),

                const _SectionHeader('Developer'),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SecondaryButton(
                    label: 'Send test notification',
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    onPressed: _testNotification,
                  ),
                ),

                // FCM token (for debugging)
                if (NotificationService.instance.fcmToken != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FCM Token', style: AppTextStyles.label),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.sage100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            NotificationService.instance.fcmToken!,
                            style: AppTextStyles.bodySm.copyWith(
                              fontFamily: 'monospace',
                              color: AppColors.sage700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onEnable;
  const _PermissionBanner({required this.onEnable});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warm50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.warm200),
    ),
    child: Row(
      children: [
        const Icon(Icons.notifications_off_outlined, color: AppColors.warm600, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications off', style: AppTextStyles.h3.copyWith(color: AppColors.warm800)),
              const SizedBox(height: 2),
              Text("Enable to get course and quiz reminders.",
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.warm600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onEnable,
          style: TextButton.styleFrom(foregroundColor: AppColors.warm600),
          child: const Text('Enable'),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(title.toUpperCase(), style: AppTextStyles.label),
  );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.sage100),
    ),
    child: ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: AppTextStyles.bodySm),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.sage600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
  );
}
