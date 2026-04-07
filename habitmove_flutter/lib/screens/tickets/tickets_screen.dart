import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/extra_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  static const _base = 'https://habitmove.com/api/v1';

  List<TicketModel> _tickets = [];
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
      final res = await http.get(Uri.parse('$_base/tickets'), headers: _headers);
      final data = jsonDecode(res.body);
      final list = data['tickets'] ?? data['data'] ?? data;
      setState(() {
        _tickets = (list as List).map((t) => TicketModel.fromJson(t)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _CreateTicketScreen(headers: _headers)),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sage50,
    appBar: AppBar(
      title: const Text('Support'),
      backgroundColor: AppColors.sage800,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
          fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: _openCreate,
          tooltip: 'New ticket',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? ErrorRetry(message: _error!, onRetry: _load)
            : _tickets.isEmpty
                ? EmptyState(
                    icon: Icons.support_agent_outlined,
                    title: 'No tickets yet',
                    subtitle: 'Need help? Open a support ticket and we\'ll get back to you.',
                    action: PrimaryButton(
                      label: 'Create ticket',
                      width: 200,
                      onPressed: _openCreate,
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.sage600,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _TicketCard(
                        ticket: _tickets[i],
                        headers: _headers,
                        onRefresh: _load,
                      ),
                    ),
                  ),
    floatingActionButton: _tickets.isNotEmpty
        ? FloatingActionButton(
            onPressed: _openCreate,
            backgroundColor: AppColors.sage700,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          )
        : null,
  );
}

// ─── Ticket card ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final Map<String, String> headers;
  final VoidCallback onRefresh;
  const _TicketCard({required this.ticket, required this.headers, required this.onRefresh});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TicketDetailScreen(ticket: ticket, headers: headers)),
    ).then((_) => onRefresh()),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ticket.subject, style: AppTextStyles.h3,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: ticket.status, color: ticket.statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sage50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sage200),
                ),
                child: Text(ticket.category,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.sage600)),
              ),
              const Spacer(),
              Text(
                '${ticket.replies.length} repl${ticket.replies.length == 1 ? 'y' : 'ies'}',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 16),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      status.replaceAll('_', ' ').toUpperCase(),
      style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: color, fontFamily: 'DMSans'),
    ),
  );
}

// ─── Ticket Detail & Reply ────────────────────────────────────────────────────

class _TicketDetailScreen extends StatefulWidget {
  final TicketModel ticket;
  final Map<String, String> headers;
  const _TicketDetailScreen({required this.ticket, required this.headers});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  static const _base = 'https://habitmove.com/api/v1';
  final _replyCtrl = TextEditingController();
  bool _sending = false;
  late TicketModel _ticket;

  @override
  void initState() { super.initState(); _ticket = widget.ticket; _load(); }

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await http.get(
          Uri.parse('$_base/tickets/${_ticket.id}'), headers: widget.headers);
      final data = jsonDecode(res.body);
      setState(() => _ticket = TicketModel.fromJson(data['ticket'] ?? data));
    } catch (_) {}
  }

  Future<void> _sendReply() async {
    final msg = _replyCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      await http.post(
        Uri.parse('$_base/tickets/${_ticket.id}/reply'),
        headers: widget.headers,
        body: jsonEncode({'message': msg}),
      );
      _replyCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sage50,
    appBar: AppBar(
      title: Text(_ticket.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: AppColors.sage800,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 20, color: Colors.white),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _StatusBadge(status: _ticket.status, color: _ticket.statusColor),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Original ticket
              _ReplyBubble(
                author: 'You',
                message: _ticket.subject,
                isSupport: false,
                isFirst: true,
              ),
              ..._ticket.replies.map((r) => _ReplyBubble(
                author: r.user?['name'] ?? 'Support',
                message: r.message,
                isSupport: (r.user?['role'] ?? 1) == 0,
                timestamp: r.createdAt,
              )),
            ],
          ),
        ),
        // Reply input
        if (_ticket.status != 'closed' && _ticket.status != 'resolved')
          _ReplyBar(
            controller: _replyCtrl,
            sending: _sending,
            onSend: _sendReply,
          ),
        if (_ticket.status == 'closed' || _ticket.status == 'resolved')
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Text(
              'This ticket is ${_ticket.status}.',
              style: AppTextStyles.body.copyWith(color: AppColors.grey400),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}

class _ReplyBubble extends StatelessWidget {
  final String author;
  final String message;
  final bool isSupport;
  final bool isFirst;
  final String? timestamp;
  const _ReplyBubble({
    required this.author,
    required this.message,
    required this.isSupport,
    this.isFirst = false,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isSupport ? AppColors.sage50 : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isSupport ? AppColors.sage200 : AppColors.sage100,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: isSupport ? AppColors.sage200 : AppColors.warm100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSupport ? Icons.support_agent_rounded : Icons.person_rounded,
                size: 15,
                color: isSupport ? AppColors.sage700 : AppColors.warm600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isSupport ? '🛡 $author' : author,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (isFirst)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sage100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Original', style: AppTextStyles.bodySm.copyWith(color: AppColors.sage600)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(message, style: AppTextStyles.body),
      ],
    ),
  );
}

class _ReplyBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _ReplyBar({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      left: 16, right: 16, top: 10,
      bottom: MediaQuery.of(context).padding.bottom + 10,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.sage100)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Write a reply…',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.sage50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.sage200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.sage200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.sage500, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: sending ? null : onSend,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: sending ? AppColors.sage300 : AppColors.sage700,
              shape: BoxShape.circle,
            ),
            child: sending
                ? const Center(child: SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    ),
  );
}

// ─── Create Ticket Screen ─────────────────────────────────────────────────────

class _CreateTicketScreen extends StatefulWidget {
  final Map<String, String> headers;
  const _CreateTicketScreen({required this.headers});

  @override
  State<_CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<_CreateTicketScreen> {
  static const _base = 'https://habitmove.com/api/v1';
  static const _categories = [
    'Account Issue', 'Billing', 'Course Content',
    'Technical Problem', 'Certificate', 'Other',
  ];

  final _formKey  = GlobalKey<FormState>();
  final _subject  = TextEditingController();
  final _message  = TextEditingController();
  String _category = 'Account Issue';
  bool _sending = false;
  String? _error;

  @override
  void dispose() { _subject.dispose(); _message.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _sending = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('$_base/tickets'),
        headers: widget.headers,
        body: jsonEncode({
          'subject': _subject.text.trim(),
          'category': _category,
          'message': _message.text.trim(),
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
      } else {
        final data = jsonDecode(res.body);
        setState(() { _error = data['message'] ?? 'Failed to create ticket'; _sending = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sage50,
    appBar: AppBar(
      title: const Text('New support ticket'),
      backgroundColor: AppColors.sage800,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 20, color: Colors.white),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              AlertBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            Text('Subject', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subject,
              style: AppTextStyles.body,
              decoration: const InputDecoration(hintText: 'Briefly describe your issue'),
              validator: (v) => v!.trim().length >= 5 ? null : 'Please enter a subject',
            ),
            const SizedBox(height: 20),

            Text('Category', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sage200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  borderRadius: BorderRadius.circular(14),
                  style: AppTextStyles.body.copyWith(color: AppColors.sage900),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Message', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _message,
              maxLines: 6,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                hintText: 'Describe your issue in detail…',
                alignLabelWithHint: true,
              ),
              validator: (v) => v!.trim().length >= 20 ? null : 'Please provide more detail (20+ chars)',
            ),
            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Submit ticket',
              loading: _sending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
