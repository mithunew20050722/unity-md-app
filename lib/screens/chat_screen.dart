import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String phone;
  const ChatScreen({super.key, required this.phone});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _msgs = [];
  bool   _loading  = true;
  bool   _sending  = false;
  bool   _setup    = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Check if chat group exists
      final jidRes = await ApiService.chatJid(widget.phone);
      if (!mounted) return;

      if (jidRes['jid'] == null) {
        // Need setup
        setState(() { _loading = false; _setup = true; });
        return;
      }

      await _loadMessages();
      // Poll every 5s
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to load chat.'; });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.chatMessages(widget.phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        final msgs = (res['messages'] as List)
            .map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() { _msgs = msgs; _loading = false; _setup = false; });
        _scrollBottom();
      }
    } catch (_) {}
  }

  Future<void> _setupChat() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.chatSetup(widget.phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() { _setup = false; });
        await _loadMessages();
        _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
      } else {
        setState(() { _loading = false; _error = res['error'] ?? 'Setup failed.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Server unreachable.'; });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    try {
      await ApiService.chatSend(widget.phone, text);
      // Optimistic add
      setState(() {
        _msgs.add({
          'id':     'local_${DateTime.now().millisecondsSinceEpoch}',
          'fromMe': true,
          'text':   text,
          'type':   'text',
          'time':   DateTime.now().millisecondsSinceEpoch,
        });
        _sending = false;
      });
      _scrollBottom();
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  String _time(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030610),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white60, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF25D366).withOpacity(0.15),
              border: Border.all(
                  color: const Color(0xFF25D366).withOpacity(0.3)),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Color(0xFF25D366), size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
            const Text('UNITY-MD Chat',
                style: TextStyle(fontFamily: 'monospace',
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text('+${widget.phone}',
                style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 10, color: Color(0xFF4A5280))),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white38, size: 20),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF25D366)))
          : _setup
              ? _setupView()
              : Column(children: [
                  if (_error != null) _errorBar(),
                  Expanded(child: _msgList()),
                  _inputBar(),
                ]),
    );
  }

  // ── Setup view ─────────────────────────────────────────────
  Widget _setupView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF25D366).withOpacity(0.1),
            border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.3)),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF25D366), size: 36),
        ),
        const SizedBox(height: 24),
        const Text('Setup App Chat',
            style: TextStyle(fontFamily: 'monospace',
                fontSize: 18, fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 12),
        const Text(
          'Creates a WhatsApp group linked to your bot.\n'
          'Startup messages & voice notes will appear there.',
          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        if (_error != null) Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(_error!, style: const TextStyle(
              color: Color(0xFFFF4757), fontSize: 12)),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _setupChat,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text('Create Bot Chat Group',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ]),
    ),
  );

  // ── Error bar ──────────────────────────────────────────────
  Widget _errorBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFFFF4757).withOpacity(0.1),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(_error!, style: const TextStyle(
          color: Color(0xFFFF4757), fontSize: 12))),
    ]),
  );

  // ── Message list ───────────────────────────────────────────
  Widget _msgList() => _msgs.isEmpty
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF4A5280), size: 40),
          const SizedBox(height: 12),
          const Text('No messages yet',
              style: TextStyle(color: Color(0xFF4A5280), fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Bot startup messages will appear here.',
              style: TextStyle(color: Color(0xFF2A3050), fontSize: 11)),
        ]))
      : ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: _msgs.length,
          itemBuilder: (_, i) => _msgBubble(_msgs[i]),
        );

  // ── Message bubble ─────────────────────────────────────────
  Widget _msgBubble(Map<String, dynamic> msg) {
    final fromMe = msg['fromMe'] as bool? ?? false;
    final isVoice = msg['type'] == 'audio';
    final text = msg['text'] as String? ?? '';
    final time = msg['time'] as int? ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left:  fromMe ? 48 : 0,
        right: fromMe ? 0  : 48,
      ),
      child: Align(
        alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            gradient: fromMe
                ? const LinearGradient(
                    colors: [Color(0xFF1A3A2A), Color(0xFF0D2018)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)
                : const LinearGradient(
                    colors: [Color(0xFF0D1117), Color(0xFF0A0F1A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(16),
              topRight:    const Radius.circular(16),
              bottomLeft:  Radius.circular(fromMe ? 16 : 4),
              bottomRight: Radius.circular(fromMe ? 4  : 16),
            ),
            border: Border.all(
              color: fromMe
                  ? const Color(0xFF25D366).withOpacity(0.25)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: fromMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!fromMe) const Text('UNITY-MD',
                  style: TextStyle(fontFamily: 'monospace',
                      fontSize: 10, color: Color(0xFF25D366),
                      fontWeight: FontWeight.w700)),
              if (!fromMe) const SizedBox(height: 4),
              if (isVoice)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.mic_rounded,
                      color: fromMe
                          ? const Color(0xFF25D366)
                          : const Color(0xFF00E5FF),
                      size: 18),
                  const SizedBox(width: 8),
                  Text('Voice Note',
                      style: TextStyle(
                          color: fromMe
                              ? const Color(0xFF25D366)
                              : const Color(0xFF00E5FF),
                          fontSize: 13,
                          fontStyle: FontStyle.italic)),
                ])
              else
                Text(text, style: const TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.4)),
              const SizedBox(height: 4),
              Text(_time(time), style: const TextStyle(
                  fontSize: 10, color: Color(0xFF4A5280),
                  fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────
  Widget _inputBar() => Container(
    padding: EdgeInsets.fromLTRB(
        12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(
      color: const Color(0xFF030610),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
    ),
    child: Row(children: [
      Expanded(child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.15)),
        ),
        child: TextField(
          controller: _ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Type a message...',
            hintStyle: TextStyle(color: Color(0xFF4A5280), fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
          maxLines: null,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
        ),
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: _sending
                    ? [Colors.white12, Colors.white12]
                    : const [Color(0xFF25D366), Color(0xFF00C853)]),
            shape: BoxShape.circle,
            boxShadow: _sending ? [] : [BoxShadow(
                color: const Color(0xFF25D366).withOpacity(0.4),
                blurRadius: 12)],
          ),
          child: _sending
              ? const Center(child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)))
              : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}
