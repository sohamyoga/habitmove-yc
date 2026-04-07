import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../models/extra_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// ─── Ticket list screen ───────────────────────────────────────────────────────

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse('$_base/tickets'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['tickets'] ?? data['data'] ?? [];
        setState(() {
          _tickets = (list as List).map((t) => TicketModel.fromJson(t)).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load tickets'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
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
          tooltip: 'New ticket',
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const NewTicketScreen()),
            );
            if (created == true) _load();
          },
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.sage700,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New ticket'),
      onPressed: () async {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const NewTicketScreen()),
        );
        if (created == true) _load();
      },
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? ErrorRetry(message: _error!, onRetry: _load)
            : _tickets.isEmpty
                ? const EmptyState(
                    icon: Icons.support_agent_outlined,
                    title: 'No tickets yet',
                    subtitle: 'Tap + to create your first support ticket.',
                  )
                : RefreshIndicator(
                    color: AppColors.sage600,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _TicketCard(
                        ticket: _tickets[i],
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                              builder: (_) => TicketDetailScreen(ticket: _tickets[i])),
                        ),
                      ),
                    ),
                  ),
  );
}

// ─── Ticket card ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;
  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
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
                child: Text(ticket.subject,
                    style: AppTextStyles.h3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: ticket.status, color: ticket.statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              AppBadge(label: ticket.category),
              const SizedBox(width: 8),
              Text(
                _formatDate(ticket.createdAt),
                style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400),
              ),
              const Spacer(),
              if (ticket.replies.isNotEmpty) ...[
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 13, color: AppColors.grey400),
                const SizedBox(width: 4),
                Text('${ticket.replies.length}',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
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
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4),
    ),
  );
}

// ─── Ticket detail + reply ────────────────────────────────────────────────────

class TicketDetailScreen extends StatefulWidget {
  final TicketModel ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  static const _base = 'https://habitmove.com/api/v1';
  final _replyCtrl = TextEditingController();
  List<TicketReply> _replies = [];
  bool _sending = false;
  String? _sendError;

  String? get _token => context.read<AuthProvider>().token;
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  @override
  void initState() {
    super.initState();
    _replies = List.from(widget.ticket.replies);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final msg = _replyCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() { _sending = true; _sendError = null; });
    try {
      final res = await http.post(
        Uri.parse('$_base/tickets/${widget.ticket.id}/reply'),
        headers: _headers,
        body: jsonEncode({'message': msg}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final reply = TicketReply.fromJson(
            data['reply'] ?? {'id': DateTime.now().millisecondsSinceEpoch, 'message': msg, 'created_at': DateTime.now().toIso8601String()});
        setState(() { _replies.add(reply); });
        _replyCtrl.clear();
      } else {
        setState(() => _sendError = 'Could not send reply');
      }
    } catch (e) {
      setState(() => _sendError = e.toString());
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: Text('#${widget.ticket.id} – ${widget.ticket.subject}',
            style: AppTextStyles.h3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.sage900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: Column(
        children: [
          // Ticket info bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                AppBadge(label: widget.ticket.category),
                const SizedBox(width: 8),
                _StatusBadge(status: widget.ticket.status, color: widget.ticket.statusColor),
                const Spacer(),
                Text(
                  'Ticket #${widget.ticket.id}',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Replies thread
          Expanded(
            child: _replies.isEmpty
                ? const Center(
                    child: Text('No replies yet.',
                        style: AppTextStyles.body),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _replies.length,
                    itemBuilder: (ctx, i) {
                      final r = _replies[i];
                      final isMe = r.user?['id'] == me?.id;
                      return _ReplyBubble(reply: r, isMe: isMe);
                    },
                  ),
          ),

          // Error
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AlertBanner(message: _sendError!),
            ),

          // Reply input
          Container(
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
                    controller: _replyCtrl,
                    minLines: 1,
                    maxLines: 4,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Write a reply…',
                      hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
                      filled: true,
                      fillColor: AppColors.sage50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.sage200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.sage200)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendReply,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _sending ? AppColors.sage300 : AppColors.sage700,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyBubble extends StatelessWidget {
  final TicketReply reply;
  final bool isMe;
  const _ReplyBubble({required this.reply, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = reply.user?['name'] as String? ?? (isMe ? 'You' : 'Support');
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(initials: initials, size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text(name,
                        style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.sage600, fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.sage700 : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.sage100),
                  ),
                  child: Text(
                    reply.message,
                    style: AppTextStyles.body.copyWith(
                        color: isMe ? Colors.white : AppColors.sage900),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(_formatTime(reply.createdAt),
                      style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.grey400, fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

// ─── New ticket screen ────────────────────────────────────────────────────────

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});
  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  static const _base = 'https://habitmove.com/api/v1';

  final _formKey    = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _msgCtrl    = TextEditingController();
  String _category  = 'General';
  bool _submitting  = false;
  String? _error;

  static const _categories = [
    'General', 'Account Issue', 'Technical Problem',
    'Billing', 'Course Content', 'Other',
  ];

  String? get _token => context.read<AuthProvider>().token;
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('$_base/tickets'),
        headers: _headers,
        body: jsonEncode({
          'subject': _subjectCtrl.text.trim(),
          'category': _category,
          'message': _msgCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
      } else {
        final data = jsonDecode(res.body);
        setState(() { _error = data['message'] ?? 'Could not create ticket'; _submitting = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sage50,
    appBar: AppBar(
      title: const Text('New Ticket'),
      backgroundColor: AppColors.sage800,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
          fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
              controller: _subjectCtrl,
              style: AppTextStyles.body,
              decoration: const InputDecoration(hintText: 'e.g. Cannot access my course'),
              validator: (v) => v!.trim().length >= 5 ? null : 'Enter a subject (min 5 chars)',
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
              child: DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: AppTextStyles.body),
                )).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
            const SizedBox(height: 20),

            Text('Message', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _msgCtrl,
              minLines: 5,
              maxLines: 10,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                hintText: 'Describe your issue in detail…',
                alignLabelWithHint: true,
              ),
              validator: (v) => v!.trim().length >= 20
                  ? null
                  : 'Please provide more detail (min 20 chars)',
            ),
            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Submit ticket',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
