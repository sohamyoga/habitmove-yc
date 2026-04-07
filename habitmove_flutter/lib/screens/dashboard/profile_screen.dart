import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../certificates/certificates_screen.dart';
import '../membership/membership_screen.dart';
import '../notifications/notification_settings_screen.dart';
import '../support/support_screen.dart';
import '../tickets/tickets_screen.dart';
import '../offline/offline_manager_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.sage50,
        body: EmptyState(
          icon: Icons.person_outline_rounded,
          title: 'Not signed in',
          subtitle: 'Sign in to view your profile.',
          action: PrimaryButton(
            label: 'Sign in',
            width: 180,
            onPressed: () => Navigator.pushNamed(context, '/auth'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(color: AppColors.sage800),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 24,
                left: 24, right: 24, bottom: 32,
              ),
              child: Column(
                children: [
                  UserAvatar(initials: user.initials, size: 72),
                  const SizedBox(height: 14),
                  Text(user.name,
                      style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(user.email, style: AppTextStyles.body.copyWith(color: AppColors.sage300)),
                  const SizedBox(height: 16),
                  if (user.walletBalance > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warm600.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.warm500.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: AppColors.warm300, size: 16),
                          const SizedBox(width: 6),
                          Text('£${user.walletBalance.toStringAsFixed(2)} wallet',
                              style: AppTextStyles.body.copyWith(color: AppColors.warm200)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Menu items
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.sage800,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.sage50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.workspace_premium_outlined,
                      label: 'My Certificates',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CertificatesScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.card_membership_outlined,
                      label: 'Membership',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MembershipScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Purchase History',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.support_agent_outlined,
                      label: 'Support',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const TicketsScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.offline_bolt_outlined,
                      label: 'Offline & Storage',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const OfflineManagerScreen())),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign out',
                      color: AppColors.error,
                      onTap: () async {
                        final confirmed = await _confirmLogout(context);
                        if (confirmed == true && context.mounted) {
                          await context.read<AuthProvider>().logout();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Sign out?', style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22)),
      content: const Text('You'll need to sign back in to access your courses.',
          style: AppTextStyles.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign out', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: (color ?? AppColors.sage600).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color ?? AppColors.sage600, size: 20),
    ),
    title: Text(label, style: AppTextStyles.body.copyWith(
        color: color ?? AppColors.sage900, fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 20),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  );
}
