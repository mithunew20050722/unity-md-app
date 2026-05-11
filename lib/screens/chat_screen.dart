import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

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

  final Map<String, AudioPlayer> _players  = {};
  String? _playingId;

  // ── Phone storage: /sdcard/UNITY-MD/chats/<phone>.json ────
  Future<File> _chatFile() async {
    final base = await getExternalStorageDirectory();
    final dir  = Directory(
      '${base!.parent.parent.parent.parent.path}/UNITY-MD/chats');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${widget.phone}.json');
  }

  Future<Directory> _voiceDir() async {
    final base = await getExternalStorageDirectory();
    final dir  = Directory(
      '${base!.parent.parent.parent.parent.path}/UNITY-MD/voice');
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

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    for (final p in _players.values) p.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });

    // Show local messages instantly
    final local = await _loadLocal();
    if (local.isNotEmpty && mounted) {
      setState(() { _msgs = local; _loading = false; });
      _scrollBottom();
    }

    try {
      final jidRes = await ApiService.chatJid(widget.phone);
      if (!mounted) return;
      if (jidRes['jid'] == null) {
        setState(() { _loading = false; _setup = true; });
        return;
      }
      await _loadMessages();
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to connect.'; });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.chatMessages(widget.phone);
      if (!mounted) return;
      if (res['ok'] == true) {
        final server = (res['messages'] as List)
            .map((e) => Map<String, dynamic>.from(e)).toList();
        // Keep local-only optimistic messages
        final serverIds = server.map((m) => m['id']).toSet();
        final localOnly = _msgs.where((m) =>
            (m['id'] as String).startsWith('local_') &&
            !serverIds.contains(m['id'])).toList();
        final merged = [...server, ...localOnly]
          ..sort((a,b) => (a['time'] as int).compareTo(b['time'] as int));
        setState(() { _msgs = merged; _loading = false; _setup = false; });
        await _saveMsgs(merged);
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
    final localMsg = {
      'id':     'local_${DateTime.now().millisecondsSinceEpoch}',
      'fromMe': true,
      'text':   text,
      'type':   'text',
      'time':   DateTime.now().millisecondsSinceEpoch,
    };
    setState(() { _msgs.add(localMsg); _sending = true; });
    await _saveMsgs(_msgs);
    _scrollBottom();
    try {
      await ApiService.chatSend(widget.phone, text);
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  // ── Voice playback ─────────────────────────────────────────
  Future<void> _toggleVoice(Map<String, dynamic> msg) async {
    final id       = msg['id'] as String;
    final audioUrl = msg['audioUrl'] as String?;
    if (audioUrl == null) return;

    if (_playingId != null && _playingId != id) {
      await _players[_playingId]?.stop();
      setState(() => _playingId = null);
    }
    if (_playingId == id) {
      await _players[id]?.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = id);
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
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030610),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white60, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF25D366).withOpacity(0.15),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF25D366), size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            const Text('UNITY-MD Chat',
                style: TextStyle(fontFamily: 'monospace',
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('+${widget.phone}',
                style: const TextStyle(fontFamily: 'monospace',
                    fontSize: 10, color: Color(0xFF4A5280))),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)))
          : _setup ? _setupView()
          : Column(children: [
              if (_error != null) _errorBar(),
              Expanded(child: _msgList()),
              _inputBar(),
            ]),
    );
  }

  Widget _setupView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF25D366).withOpacity(0.1),
            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF25D366), size: 36),
        ),
        const SizedBox(height: 24),
        const Text('Setup App Chat',
            style: TextStyle(fontFamily: 'monospace',
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 12),
        const Text('Link your bot to this app.\nStartup messages & voice notes will appear here.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
            textAlign: TextAlign.center),
        if (_error != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _setupChat,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text('Setup Bot Chat',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ]),
    ),
  );

  Widget _errorBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFFFF4757).withOpacity(0.1),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(_error!,
          style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12))),
    ]),
  );

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

  Widget _msgBubble(Map<String, dynamic> msg) {
    final fromMe    = msg['fromMe'] as bool? ?? false;
    final isVoice   = msg['type'] == 'audio';
    final text      = msg['text'] as String? ?? '';
    final time      = msg['time'] as int? ?? 0;
    final id        = msg['id'] as String;
    final isPlaying = _playingId == id;

    return Padding(
      padding: EdgeInsets.only(bottom: 6, left: fromMe ? 48 : 0, right: fromMe ? 0 : 48),
      child: Align(
        alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
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
            crossAxisAlignment: fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!fromMe) ...[
                const Text('UNITY-MD',
                    style: TextStyle(fontFamily: 'monospace',
                        fontSize: 10, color: Color(0xFF25D366),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
              ],
              if (isVoice)
                GestureDetector(
                  onTap: () => _toggleVoice(msg),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlaying
                            ? const Color(0xFF25D366)
                            : const Color(0xFF25D366).withOpacity(0.2),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: List.generate(12, (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 3,
                        height: isPlaying
                            ? (4 + (i % 4) * 5).toDouble()
                            : (3 + (i % 3) * 4).toDouble(),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? const Color(0xFF25D366)
                              : const Color(0xFF25D366).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ))),
                      const SizedBox(height: 4),
                      Text(isPlaying ? 'Playing...' : 'Voice Note',
                          style: TextStyle(
                            color: isPlaying ? const Color(0xFF25D366) : Colors.white38,
                            fontSize: 11, fontStyle: FontStyle.italic)),
                    ]),
                  ]),
                )
              else
                Text(text, style: const TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.4)),
              const SizedBox(height: 4),
              Text(_time(time), style: const TextStyle(
                  fontSize: 10, color: Color(0xFF4A5280), fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBar() => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(
      color: const Color(0xFF030610),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
    ),
    child: Row(children: [
      Expanded(child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.15)),
        ),
        child: TextField(
          controller: _ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Type a message...',
            hintStyle: TextStyle(color: Color(0xFF4A5280), fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}
