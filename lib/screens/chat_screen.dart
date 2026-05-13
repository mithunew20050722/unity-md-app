import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ChatScreen extends StatefulWidget {
  final String phone;
  const ChatScreen({super.key, required this.phone});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _ctrl      = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll    = ScrollController();

  List<Map<String, dynamic>> _msgs = [];
  final Set<String> _deletedIds = {};
  bool   _loading = true;
  bool   _sending = false;
  bool   _setup   = false;
  String? _error;
  Map<String, dynamic>? _replyTo;
  Timer? _pollTimer;

  final Map<String, AudioPlayer> _players = {};
  String? _playingId;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // ── Local file paths ──────────────────────────────────────
  Future<String> _unityRootPath() async {
    // Use app-private documents dir — no storage permissions needed
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/UNITY-MD';
  }

  Future<File> _chatFile() async {
    final root = await _unityRootPath();
    final dir  = Directory('$root/chats');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${widget.phone}.json');
  }

  Future<Directory> _voiceDir() async {
    final root = await _unityRootPath();
    final dir  = Directory('$root/voice');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _saveMsgs(List<Map<String, dynamic>> msgs) async {
    try {
      final file = await _chatFile();
      await file.writeAsString(jsonEncode(msgs));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadLocal() async {
    try {
      final file = await _chatFile();
      if (!await file.exists()) return [];
      final List decoded = jsonDecode(await file.readAsString());
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { return []; }
  }

  Future<String?> _cacheVoice(String msgId, String url) async {
    try {
      final dir  = await _voiceDir();
      final file = File('${dir.path}/$msgId.ogg');
      if (await file.exists()) return file.path;
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        await file.writeAsBytes(resp.bodyBytes);
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    _pulseCtrl.dispose();
    for (final p in _players.values) p.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });

    // ① Show local messages immediately — no blank screen on open
    final local = await _loadLocal();
    if (local.isNotEmpty && mounted) {
      setState(() { _msgs = local; _loading = false; });
      _scrollBottom();
    }

    try {
      // Activate virtual channel wrapper on backend (no group needed)
      await ApiService.chatSetup(widget.phone);
      if (!mounted) return;
      setState(() { _setup = false; });
      await _loadMessages();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
      // Still start polling — local messages are visible
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
    }
  }

  // ── Load messages — BUG FIX: never wipe local on empty server ──
  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.chatMessages(widget.phone);
      if (!mounted) return;
      if (res['ok'] != true) return;

      final server = (res['messages'] as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();

      // ✅ FIX: Server returned empty (restart/RAM wiped) → keep what we have
      if (server.isEmpty) {
        if (mounted) setState(() { _loading = false; _setup = false; });
        return;
      }

      // ✅ FIX: Merge properly — add only new server messages, never discard local
      // Also skip any messages the user has locally deleted (_deletedIds blacklist)
      final existingIds = _msgs.map((m) => m['id']?.toString() ?? '').toSet();
      final newFromServer = server
          .where((m) {
            final id = m['id']?.toString() ?? '';
            return !existingIds.contains(id) && !_deletedIds.contains(id);
          })
          .toList();

      if (newFromServer.isEmpty) {
        if (mounted) setState(() { _loading = false; _setup = false; });
        return; // Nothing new — no setState needed for messages
      }

      final merged = [..._msgs, ...newFromServer];
      merged.sort((a, b) =>
          ((a['ts'] ?? a['time'] ?? 0) as int)
              .compareTo((b['ts'] ?? b['time'] ?? 0) as int));

      // Keep max 300 messages
      final trimmed = merged.length > 300
          ? merged.sublist(merged.length - 300)
          : merged;

      if (mounted) setState(() { _msgs = trimmed; _loading = false; _setup = false; });
      await _saveMsgs(trimmed);
      _scrollBottom();
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
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Server unreachable.'; });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    HapticFeedback.lightImpact();

    // Reply: keep replyText for local UI display only
    // Send ONLY the actual typed text to backend (no quote prefix — breaks command parsing)
    final replyMsg  = _replyTo;
    final replyText = replyMsg != null
        ? replyMsg['text']?.toString() ?? ''
        : null;

    final localId  = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final localMsg = {
      'id':     localId,
      'fromMe': true,
      'text':   text,
      'type':   'text',
      'ts':     DateTime.now().millisecondsSinceEpoch,
      if (replyText != null && replyText.isNotEmpty) 'replyText': replyText,
    };

    setState(() {
      _msgs.add(localMsg);
      _sending = true;
      _replyTo = null; // clear reply
    });
    await _saveMsgs(_msgs);
    _scrollBottom();

    try {
      // Send only the actual command text — no quote prepended
      await ApiService.chatSend(widget.phone, text);
      if (mounted) setState(() {
        final idx = _msgs.indexWhere((m) => m['id'] == localId);
        if (idx != -1) {
          _msgs[idx] = Map<String, dynamic>.from(_msgs[idx])
            ..['id'] = 'sent_${DateTime.now().millisecondsSinceEpoch}';
        }
      });
      _saveMsgs(_msgs);
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  // ── Voice ─────────────────────────────────────────────────
  Future<void> _toggleVoice(Map<String, dynamic> msg) async {
    final id       = msg['id'] as String;
    final audioUrl = msg['audioUrl'] as String?;
    if (audioUrl == null) return;

    if (_playingId != null && _playingId != id) {
      await _players[_playingId]?.stop();
      if (mounted) setState(() => _playingId = null);
    }
    if (_playingId == id) {
      await _players[id]?.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    if (mounted) setState(() => _playingId = id);
    try {
      final fullUrl = '${ApiService.base.replaceAll('/api/app', '')}$audioUrl';
      final cached  = await _cacheVoice(id, fullUrl);
      final player  = _players[id] ?? AudioPlayer();
      _players[id]  = player;
      if (cached != null) {
        await player.setFilePath(cached);
      } else {
        await player.setUrl(fullUrl);
      }
      await player.play();
      player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingId = null);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
  }

  void _scrollBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut);
      }
    });
  }

  String _time(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: _buildAppBar(),
      body: _loading
          ? _loadingView()
          : _setup
          ? _setupView()
          : Column(children: [
              if (_error != null) _errorBar(),
              Expanded(child: _msgList()),
              _inputBar(),
            ]),
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: const Color(0xFF030610),
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white54, size: 18),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(children: [
      // Animated status ring
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF25D366)
                  .withOpacity(0.06 + _pulseAnim.value * 0.05),
              border: Border.all(
                color: const Color(0xFF25D366)
                    .withOpacity(0.2 + _pulseAnim.value * 0.15),
              ),
            ),
          ),
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0A1A0E),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Color(0xFF25D366), size: 20),
          ),
        ]),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('UNITY-MD', style: TextStyle(
              fontFamily: 'monospace', fontSize: 14,
              fontWeight: FontWeight.w900, color: Colors.white,
              letterSpacing: 1)),
          Row(children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF25D366),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.8),
                    blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 5),
            Text('+${widget.phone}', style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: Color(0xFF3A4270))),
          ]),
        ],
      )),
    ]),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded, color: Colors.white24, size: 20),
        onPressed: _loadMessages,
        tooltip: 'Refresh',
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            const Color(0xFF25D366).withOpacity(0.2),
            Colors.transparent,
          ]),
        ),
      ),
    ),
  );

  // ── Loading view ──────────────────────────────────────────
  Widget _loadingView() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF25D366)
                .withOpacity(0.06 + _pulseAnim.value * 0.06),
            border: Border.all(
              color: const Color(0xFF25D366)
                  .withOpacity(0.2 + _pulseAnim.value * 0.2),
            ),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF25D366), size: 28),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Connecting...', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12, color: Color(0xFF3A4270))),
    ]),
  );

  // ── Setup view ────────────────────────────────────────────
  Widget _setupView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Icon with glow rings
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Stack(alignment: Alignment.center, children: [
            Container(
              width: 100 + _pulseAnim.value * 8,
              height: 100 + _pulseAnim.value * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF25D366)
                    .withOpacity(0.04 + _pulseAnim.value * 0.03),
              ),
            ),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A1A0E),
                border: Border.all(
                  color: const Color(0xFF25D366)
                      .withOpacity(0.3 + _pulseAnim.value * 0.2),
                  width: 2,
                ),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF25D366)
                        .withOpacity(0.15 + _pulseAnim.value * 0.1),
                    blurRadius: 20, spreadRadius: 4)],
              ),
              child: const Icon(Icons.forum_rounded,
                  color: Color(0xFF25D366), size: 34),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF00E5FF)])
              .createShader(r),
          child: const Text('App Chat Setup', style: TextStyle(
              fontFamily: 'monospace', fontSize: 20,
              fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Link your bot to this app.\nStartup messages & bot replies\nwill appear here.',
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.7),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4757).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF4757), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(
                  color: Color(0xFFFF4757), fontSize: 12))),
            ]),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 54,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _setupChat,
            icon: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: Text(_loading ? 'Setting up...' : 'Setup Bot Chat',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ]),
    ),
  );

  // ── Error bar ─────────────────────────────────────────────
  Widget _errorBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFF4757).withOpacity(0.08),
      border: const Border(
          bottom: BorderSide(color: Color(0xFFFF4757), width: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(_error!,
          style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12))),
      GestureDetector(
        onTap: () => setState(() => _error = null),
        child: const Icon(Icons.close, color: Color(0xFFFF4757), size: 14),
      ),
    ]),
  );

  // ── Message list ──────────────────────────────────────────
  Widget _msgList() => _msgs.isEmpty
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF060A14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: Color(0xFF3A4270), size: 28),
          ),
          const SizedBox(height: 16),
          const Text('No messages yet', style: TextStyle(
              color: Color(0xFF3A4270), fontSize: 14,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Type a command or wait for\nbot startup messages.',
              style: TextStyle(color: Color(0xFF252A40), fontSize: 12,
                  height: 1.5), textAlign: TextAlign.center),
        ]))
      : ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          itemCount: _msgs.length,
          itemBuilder: (_, i) {
            final msg = _msgs[i];
            final prev = i > 0 ? _msgs[i - 1] : null;
            return _msgBubble(msg, prev);
          },
        );

  Widget _msgBubble(Map<String, dynamic> msg, Map<String, dynamic>? prev) {
    final fromMe    = msg['fromMe'] as bool? ?? false;
    final isVoice   = msg['type'] == 'audio';
    final text      = msg['text'] as String? ?? '';
    final ts        = (msg['ts'] ?? msg['time'] ?? 0) as int;
    final id        = msg['id']?.toString() ?? '';
    final isPlaying = _playingId == id;
    final isLocal   = id.startsWith('local_');

    // Show date separator
    final showDate = prev == null || !_sameDay(
        (prev['ts'] ?? prev['time'] ?? 0) as int, ts);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showDate) _dateSeparator(ts),
      Padding(
        padding: EdgeInsets.only(
            bottom: 4,
            left: fromMe ? 52 : 0,
            right: fromMe ? 0 : 52),
        child: Align(
          alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _msgOptions(msg),
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                gradient: fromMe
                    ? const LinearGradient(
                        colors: [Color(0xFF1A3D28), Color(0xFF0D2018)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : LinearGradient(
                        colors: [
                          const Color(0xFF0D1420),
                          const Color(0xFF080D18),
                        ],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(fromMe ? 18 : 4),
                  bottomRight: Radius.circular(fromMe ? 4  : 18),
                ),
                border: Border.all(
                  color: fromMe
                      ? const Color(0xFF25D366).withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  width: 1,
                ),
                boxShadow: [BoxShadow(
                    color: (fromMe
                        ? const Color(0xFF25D366)
                        : Colors.black).withOpacity(0.08),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: fromMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Bot label
                  if (!fromMe) ...[
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF00E5FF)])
                          .createShader(r),
                      child: const Text('UNITY-MD', style: TextStyle(
                          fontFamily: 'monospace', fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 5),
                  ],

                  // Reply quote preview
                  if (msg['replyText'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(
                            color: Color(0xFF25D366), width: 3)),
                      ),
                      child: Text(
                        msg['replyText'].toString().length > 60
                            ? '${msg['replyText'].toString().substring(0, 60)}...'
                            : msg['replyText'].toString(),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // Voice or text
                  if (isVoice)
                    _voiceBubble(msg, isPlaying)
                  else
                    Text(text, style: const TextStyle(
                        color: const Color(0xD1FFFFFF), fontSize: 14, height: 1.45)),

                  const SizedBox(height: 5),

                  // Timestamp + status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_time(ts), style: const TextStyle(
                          fontSize: 10, color: Color(0xFF3A4270),
                          fontFamily: 'monospace')),
                      if (fromMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isLocal ? Icons.access_time_rounded : Icons.done_all_rounded,
                          size: 12,
                          color: isLocal
                              ? const Color(0xFF3A4270)
                              : const Color(0xFF25D366),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _voiceBubble(Map<String, dynamic> msg, bool isPlaying) {
    return GestureDetector(
      onTap: () => _toggleVoice(msg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying
                  ? const Color(0xFF25D366)
                  : const Color(0xFF25D366).withOpacity(0.15),
              boxShadow: isPlaying ? [BoxShadow(
                  color: const Color(0xFF25D366).withOpacity(0.4),
                  blurRadius: 8)] : [],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Waveform bars
            Row(children: List.generate(14, (i) {
              final heights = [4.0, 8.0, 14.0, 10.0, 6.0, 12.0, 16.0,
                              8.0, 4.0, 10.0, 14.0, 6.0, 10.0, 4.0];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 2.5,
                height: isPlaying ? heights[i] : heights[i] * 0.6,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? const Color(0xFF25D366)
                      : const Color(0xFF25D366).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            })),
            const SizedBox(height: 5),
            Text(
              isPlaying ? '▶ Playing...' : '🎙 Voice Note',
              style: TextStyle(
                  color: isPlaying
                      ? const Color(0xFF25D366)
                      : Colors.white38,
                  fontSize: 10,
                  fontFamily: 'monospace'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _dateSeparator(int ts) {
    final now = DateTime.now();
    final dt  = DateTime.fromMillisecondsSinceEpoch(ts);
    String label;
    if (_sameDay(ts, now.millisecondsSinceEpoch)) {
      label = 'Today';
    } else if (_sameDay(ts,
        now.subtract(const Duration(days: 1)).millisecondsSinceEpoch)) {
      label = 'Yesterday';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.05))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF060A14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text(label, style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: Color(0xFF3A4270))),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.05))),
      ]),
    );
  }

  bool _sameDay(int ms1, int ms2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ms1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ms2);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  void _copyMsg(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Copied', style: TextStyle(fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF25D366),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _msgOptions(Map<String, dynamic> msg) {
    HapticFeedback.mediumImpact();
    final text = msg['text']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1420),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(width: 32, height: 3,
            decoration: BoxDecoration(color: Colors.white12,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Preview of message
          if (text.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Text(
                text.length > 80 ? '${text.substring(0, 80)}...' : text,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),

          // Options
          _optionTile(
            icon: Icons.reply_rounded,
            color: const Color(0xFF25D366),
            label: 'Reply',
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyTo = msg);
              _focusNode.requestFocus();
            },
          ),
          const SizedBox(height: 8),
          _optionTile(
            icon: Icons.copy_rounded,
            color: const Color(0xFF00E5FF),
            label: 'Copy',
            onTap: () {
              Navigator.pop(context);
              _copyMsg(text);
            },
          ),
          const SizedBox(height: 8),
          _optionTile(
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFFF4757),
            label: 'Delete',
            onTap: () {
              Navigator.pop(context);
              _deleteMsg(msg['id']?.toString() ?? '');
            },
          ),
        ]),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(
            color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  void _deleteMsg(String id) {
    if (id.isEmpty) return;
    _deletedIds.add(id); // permanently blacklist this ID
    setState(() => _msgs.removeWhere((m) => m['id']?.toString() == id));
    _saveMsgs(_msgs);
  }

  // ── Reply preview bar ────────────────────────────────────────
  Widget _replyBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
    decoration: const BoxDecoration(
      color: Color(0xFF030610),
      border: Border(top: BorderSide(color: Color(0xFF0D1425), width: 1)),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(
            color: const Color(0xFF25D366), width: 3)),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Replying to', style: TextStyle(
                color: Color(0xFF25D366), fontSize: 11,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              _replyTo?['text']?.toString() ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        )),
        GestureDetector(
          onTap: () => setState(() => _replyTo = null),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.close_rounded,
                color: Colors.white24, size: 18)),
        ),
      ]),
    ),
  );

  // ── Input bar ─────────────────────────────────────────────
  Widget _inputBar() => Column(mainAxisSize: MainAxisSize.min, children: [
    // Reply preview bar
    if (_replyTo != null) _replyBar(),
    Container(
    padding: EdgeInsets.fromLTRB(
        12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(
      color: const Color(0xFF030610),
      border: Border(top: BorderSide(
          color: Colors.white.withOpacity(0.04), width: 1)),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 12, offset: const Offset(0, -4))],
    ),
    child: Row(children: [
      // Text field
      Expanded(child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1420),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.12)),
        ),
        child: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Type a message or command...',
            hintStyle: const TextStyle(
                color: Color(0xFF3A4270), fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 12),
            prefixIcon: const Icon(Icons.terminal_rounded,
                color: Color(0xFF3A4270), size: 16),
          ),
          maxLines: null,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
        ),
      )),
      const SizedBox(width: 8),

      // Send button
      GestureDetector(
        onTap: _send,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _sending
                  ? [Colors.white10, Colors.white10]
                  : const [Color(0xFF25D366), Color(0xFF00C853)]),
              shape: BoxShape.circle,
              boxShadow: _sending ? [] : [BoxShadow(
                  color: const Color(0xFF25D366)
                      .withOpacity(0.35 + _pulseAnim.value * 0.15),
                  blurRadius: 12 + _pulseAnim.value * 4)],
            ),
            child: _sending
                ? const Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
          ),
        ),
      ),
    ]),
  ), // Container
  ]); // Column
}
