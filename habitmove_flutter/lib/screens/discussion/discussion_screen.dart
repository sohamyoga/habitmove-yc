import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/models.dart';
import '../../models/extra_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../services/notification_service.dart';

class DiscussionScreen extends StatefulWidget {
  final CourseModel course;
  const DiscussionScreen({super.key, required this.course});

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  static const _base = 'https://habitmove.com/api/v1';

  List<DiscussionMessage> _messages = [];
  bool _loading = true;
  String? _error;
  int? _lastId;
  bool _hasMore = true;
  bool _loadingMore = false;

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  File? _pendingFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthProvider>().token;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  void _onScroll() {
    if (_scrollCtrl.position.pixels <= 100 && _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMessages() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('$_base/courses/${widget.course.id}/discussion/messages'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      final list = (data['messages'] ?? data['data'] ?? data as List? ?? []) as List;
      final msgs = list.map((m) => DiscussionMessage.fromJson(m)).toList();
      // Reverse so newest is at bottom
      msgs.sort((a, b) => a.id.compareTo(b.id));
      setState(() {
        _messages = msgs;
        _lastId = msgs.isNotEmpty ? msgs.first.id : null;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _lastId == null) return;
    setState(() => _loadingMore = true);
    try {
      final res = await http.get(
        Uri.parse('$_base/courses/${widget.course.id}/discussion/messages?last_id=$_lastId'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      final list = (data['messages'] ?? data['data'] ?? []) as List;
      if (list.isEmpty) {
        setState(() { _hasMore = false; _loadingMore = false; });
        return;
      }
      final older = list.map((m) => DiscussionMessage.fromJson(m)).toList();
      older.sort((a, b) => a.id.compareTo(b.id));
      setState(() {
        _messages = [...older, ..._messages];
        _lastId = older.first.id;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _pendingFile == null) return;
    setState(() => _sending = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/courses/${widget.course.id}/discussion/messages'),
      );
      request.headers.addAll(_headers);
      if (text.isNotEmpty) request.fields['message'] = text;
      if (_pendingFile != null) {
        request.files.add(await http.MultipartFile.fromPath('file', _pendingFile!.path));
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final newMsg = DiscussionMessage.fromJson(data['message'] ?? data);
        setState(() {
          _messages.add(newMsg);
          _pendingFile = null;
        });
        _msgCtrl.clear();
        _scrollToBottom();

        // Fire notification for other participants (demo)
        if (text.isNotEmpty) {
          await NotificationService.instance.notifyNewMessage(
            newMsg.user.name, widget.course.title);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _pendingFile = File(picked.path));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.course.title,
                style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Discussion', style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.sage900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorRetry(message: _error!, onRetry: _loadMessages)
                    : _messages.isEmpty
                        ? _EmptyDiscussion()
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: _messages.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i == 0 && _loadingMore) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              }
                              final msg = _messages[_loadingMore ? i - 1 : i];
                              final isMe = msg.userId == me?.id;
                              return _MessageBubble(message: msg, isMe: isMe);
                            },
                          ),
          ),

          // Pending file preview
          if (_pendingFile != null)
            _FilePreview(
              file: _pendingFile!,
              onRemove: () => setState(() => _pendingFile = null),
            ),

          // Input bar
          _InputBar(
            controller: _msgCtrl,
            sending: _sending,
            onSend: _sendMessage,
            onPickImage: _pickImage,
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final DiscussionMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final time = timeago.format(DateTime.tryParse(message.createdAt) ?? DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(initials: message.user.initials, size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text(message.user.name,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.message != null && message.message!.isNotEmpty)
                        Text(
                          message.message!,
                          style: AppTextStyles.body.copyWith(
                            color: isMe ? Colors.white : AppColors.sage900,
                          ),
                        ),
                      if (message.hasFile && message.isImage && message.filePath != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            message.filePath!,
                            width: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ] else if (message.hasFile) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_file_rounded,
                                size: 16,
                                color: isMe ? Colors.white70 : AppColors.sage500),
                            const SizedBox(width: 4),
                            Text(
                              'Attachment',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: isMe ? Colors.white70 : AppColors.sage500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(time,
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400, fontSize: 10)),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      left: 12, right: 12,
      top: 10,
      bottom: MediaQuery.of(context).padding.bottom + 10,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.sage100)),
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.image_outlined, color: AppColors.sage500),
          onPressed: onPickImage,
          tooltip: 'Attach image',
        ),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 1,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Write a message…',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.sage50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.sage200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.sage200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.sage500, width: 1.5),
              ),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        _SendButton(sending: sending, onTap: onSend),
      ],
    ),
  );
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onTap;
  const _SendButton({required this.sending, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: sending ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: sending ? AppColors.sage300 : AppColors.sage700,
        shape: BoxShape.circle,
      ),
      child: sending
          ? const Center(child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
    ),
  );
}

class _FilePreview extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _FilePreview({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.sage50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.sage200),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(file.path.split('/').last,
              style: AppTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.grey400),
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

class _EmptyDiscussion extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: AppColors.sage100, shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.sage300, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('No messages yet',
            style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22, color: AppColors.sage800)),
        const SizedBox(height: 6),
        Text('Be the first to start the discussion!',
            style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
      ],
    ),
  );
}
