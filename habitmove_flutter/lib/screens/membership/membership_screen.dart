import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/extra_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  static const _base = 'https://habitmove.com/api/v1';

  List<MembershipPlan> _plans = [];
  Map<String, dynamic>? _myMembership;
  bool _loading = true;
  String? _error;
  int? _selectedPlanId;
  bool _purchasing = false;
  String _paymentMethod = 'stripe';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _token => context.read<AuthProvider>().token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final futures = await Future.wait([
        http.get(Uri.parse('$_base/membership'), headers: _headers),
        if (_token != null)
          http.get(Uri.parse('$_base/my-membership'), headers: _headers),
      ]);

      final plansData = jsonDecode(futures[0].body);
      final rawPlans = plansData['memberships'] ?? plansData['plans'] ?? plansData['data'] ?? [];
      final plans = (rawPlans as List).map((p) => MembershipPlan.fromJson(p)).toList();

      Map<String, dynamic>? myMembership;
      if (futures.length > 1 && futures[1].statusCode == 200) {
        final myData = jsonDecode(futures[1].body);
        myMembership = myData['membership'] ?? myData;
      }

      setState(() {
        _plans = plans.isNotEmpty ? plans : _demoPlans();
        _myMembership = myMembership;
        _selectedPlanId = plans.isNotEmpty ? plans[0].id : null;
        _loading = false;
      });
    } catch (e) {
      // Fallback to demo plans so the UI is always usable
      setState(() {
        _plans = _demoPlans();
        _selectedPlanId = _demoPlans()[1].id;
        _loading = false;
      });
    }
  }

  List<MembershipPlan> _demoPlans() => [
    MembershipPlan(
      id: 1, name: 'Monthly', price: 14.99, interval: 'month',
      features: ['Unlimited courses', 'All quizzes', 'Certificate downloads', 'Community access'],
      isPopular: false,
    ),
    MembershipPlan(
      id: 2, name: 'Annual', price: 99.99, interval: 'year',
      features: ['Everything in Monthly', 'Priority support', 'Exclusive content', 'Save 44%'],
      isPopular: true,
    ),
  ];

  Future<void> _subscribe() async {
    if (_selectedPlanId == null) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to subscribe')),
      );
      return;
    }

    setState(() => _purchasing = true);
    try {
      // The API's checkout handles membership too
      final res = await http.post(
        Uri.parse('$_base/checkout/course'),
        headers: _headers,
        body: jsonEncode({
          'name': auth.user!.name,
          'email': auth.user!.email,
          'membership_id': _selectedPlanId,
          'payment_method': _paymentMethod,
        }),
      );

      final data = jsonDecode(res.body);
      final link = data['payment_links']?[_paymentMethod] ?? data['redirect'];

      if (link != null) {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      } else {
        // Schedule membership expiry reminder
        await NotificationService.instance.notifyMembershipExpiring(30);
        if (mounted) _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _purchasing = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.sage100, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.sage600, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Welcome, member!',
                style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 24),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Your membership is now active. Enjoy unlimited access.',
                style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Start learning →'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelMembership() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel membership?',
            style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22)),
        content: const Text(
            'You will receive a pro-rated refund to your wallet. '
            'Access continues until the current period ends.',
            style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel membership'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.post(
        Uri.parse('$_base/membership/cancel'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Membership cancelled')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: CustomScrollView(
        slivers: [
          _buildHeroSliver(),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: ErrorRetry(message: _error!, onRetry: _load))
          else
            _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeroSliver() => SliverAppBar(
    expandedHeight: 200,
    pinned: true,
    backgroundColor: AppColors.sage900,
    foregroundColor: Colors.white,
    flexibleSpace: FlexibleSpaceBar(
      background: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(color: AppColors.sage900),
            child: Center(
              child: Opacity(
                opacity: 0.06,
                child: GridView.count(
                  crossAxisCount: 8,
                  children: List.generate(64, (_) =>
                      const Icon(Icons.circle, size: 8, color: Colors.white)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Membership', style: AppTextStyles.label.copyWith(color: AppColors.sage400, letterSpacing: 2)),
                const SizedBox(height: 6),
                const Text('Unlock everything',
                    style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 32, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Unlimited access to all courses and features.',
                    style: AppTextStyles.body.copyWith(color: AppColors.sage300)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildContent() {
    final hasMembership = _myMembership != null &&
        (_myMembership!['status'] == 'active' || _myMembership!['membership_validity_to'] != null);

    return SliverList(
      delegate: SliverChildListDelegate([
        // Active membership card
        if (hasMembership) _ActiveMembershipCard(data: _myMembership!, onCancel: _cancelMembership),

        // What you get
        const _PerksSection(),

        // Plan selector
        if (!hasMembership) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text('Choose a plan',
                style: AppTextStyles.displaySm.copyWith(fontSize: 20)),
          ),
          ..._plans.map((plan) => _PlanCard(
            plan: plan,
            selected: _selectedPlanId == plan.id,
            onSelect: () => setState(() => _selectedPlanId = plan.id),
          )),

          // Payment method
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text('Payment', style: AppTextStyles.label),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: ['stripe', 'paypal'].map((m) {
                final sel = _paymentMethod == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentMethod = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: m == 'stripe' ? 10 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.sage50 : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel ? AppColors.sage600 : AppColors.sage200,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        m == 'stripe' ? '💳  Card' : '🅿️  PayPal',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? AppColors.sage800 : AppColors.grey600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: PrimaryButton(
              label: _selectedPlanId != null
                  ? 'Subscribe · £${_plans.firstWhere((p) => p.id == _selectedPlanId, orElse: () => _plans.first).price.toStringAsFixed(2)}'
                  : 'Select a plan',
              loading: _purchasing,
              onPressed: _selectedPlanId != null ? _subscribe : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text('Cancel anytime. No hidden fees.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ]),
    );
  }
}

// ─── Active membership card ───────────────────────────────────────────────────

class _ActiveMembershipCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onCancel;
  const _ActiveMembershipCard({required this.data, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final validTo = data['membership_validity_to'] ?? data['valid_to'] ?? '';
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.sage700, AppColors.sage800],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.warm300, size: 28),
              const SizedBox(width: 10),
              const Text('Active Member',
                  style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warm400.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warm300.withOpacity(0.5)),
                ),
                child: Text('ACTIVE', style: AppTextStyles.label.copyWith(color: AppColors.warm200)),
              ),
            ],
          ),
          if (validTo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Valid until', style: AppTextStyles.bodySm.copyWith(color: AppColors.sage300)),
            const SizedBox(height: 2),
            Text(validTo, style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.sage300,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Cancel membership →'),
          ),
        ],
      ),
    );
  }
}

// ─── Perks section ────────────────────────────────────────────────────────────

class _PerksSection extends StatelessWidget {
  const _PerksSection();

  static const _perks = [
    (Icons.school_rounded,      'All courses',           'Unlimited access to the full library'),
    (Icons.quiz_rounded,        'All quizzes',           'Test your knowledge, track growth'),
    (Icons.workspace_premium_rounded, 'Certificates',    'Earn verified PDF certificates'),
    (Icons.chat_rounded,        'Community',             'Discussion forums on every course'),
    (Icons.support_agent_rounded,'Priority support',     'Faster responses from our team'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Everything included', style: AppTextStyles.displaySm.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        ..._perks.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.sage100, borderRadius: BorderRadius.circular(12)),
                child: Icon(p.$1, color: AppColors.sage600, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.$2, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(p.$3, style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              const Icon(Icons.check_rounded, color: AppColors.sage500, size: 18),
            ],
          ),
        )),
      ],
    ),
  );
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onSelect;
  const _PlanCard({required this.plan, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onSelect,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: selected ? AppColors.sage50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.sage600 : AppColors.sage200,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.sage600 : Colors.transparent,
              border: Border.all(color: selected ? AppColors.sage600 : AppColors.grey400),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plan.name, style: AppTextStyles.h2),
                    if (plan.isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warm500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('BEST VALUE',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                if (plan.features.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...plan.features.take(3).map((f) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_rounded, color: AppColors.sage500, size: 13),
                        const SizedBox(width: 5),
                        Text(f, style: AppTextStyles.bodySm),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('£${plan.price.toStringAsFixed(2)}',
                  style: AppTextStyles.h2.copyWith(color: AppColors.sage800)),
              if (plan.interval != null)
                Text('/ ${plan.interval}',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
            ],
          ),
        ],
      ),
    ),
  );
}
