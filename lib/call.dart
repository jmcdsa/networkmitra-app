import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api.dart';
import 'badge.dart';
import 'chat.dart' show asList;
import 'main.dart' show navKey;
import 'widgets.dart';

const List<String> _endedStates = ['ended', 'declined', 'cancelled', 'missed'];

void startCall(BuildContext context, int userId, String name, bool video) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => CallScreen(otherUserId: userId, name: name, video: video, incoming: false),
  ));
}

/// Looks for a call that is ringing for me, and opens the "incoming call" screen.
class CallWatcher {
  static int? shownId;
  static bool inCall = false;
  static bool _busy = false;

  static Future<void> check() async {
    if (Api.token == null || inCall || _busy) return;
    _busy = true;
    try {
      final p = await Api.get('calls/pending');
      if (p != null && p['id'] != shownId) {
        shownId = p['id'] as int;
        final other = Map<String, dynamic>.from(p['other'] as Map);
        navKey.currentState?.push(MaterialPageRoute(
          builder: (_) => IncomingCallScreen(callId: p['id'] as int, userId: other['id'] as int, name: other['name'].toString(), video: p['type'] == 'video'),
        ));
      }
    } catch (_) {
      // offline: try again at the next check
    } finally {
      _busy = false;
    }
  }
}

class IncomingCallScreen extends StatefulWidget {
  final int callId;
  final int userId;
  final String name;
  final bool video;
  const IncomingCallScreen({super.key, required this.callId, required this.userId, required this.name, required this.video});
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _t;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 2), (_) async {
      HapticFeedback.heavyImpact();
      try {
        final c = await Api.get('calls/${widget.callId}');
        if (c['status'] != 'ringing' && !_closed && mounted) {
          _closed = true;
          Navigator.of(context).pop();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _decline() async {
    _closed = true;
    try {
      await Api.post('calls/${widget.callId}/end', {});
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _accept() {
    _closed = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => CallScreen(callId: widget.callId, otherUserId: widget.userId, name: widget.name, video: widget.video, incoming: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B3B37),
        body: SafeArea(
          child: Column(children: [
            const Spacer(),
            const CircleAvatar(radius: 54, child: Icon(Icons.person, size: 60)),
            const SizedBox(height: 20),
            Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Incoming ${widget.video ? 'video' : 'audio'} call...', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Column(children: [
                  FloatingActionButton(heroTag: 'decline', backgroundColor: Colors.red, onPressed: _decline, child: const Icon(Icons.call_end, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('Decline', style: TextStyle(color: Colors.white70)),
                ]),
                Column(children: [
                  FloatingActionButton(heroTag: 'accept', backgroundColor: Colors.green, onPressed: _accept, child: Icon(widget.video ? Icons.videocam : Icons.call, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('Accept', style: TextStyle(color: Colors.white70)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class CallScreen extends StatefulWidget {
  final int? callId;
  final int otherUserId;
  final String name;
  final bool video;
  final bool incoming;
  const CallScreen({super.key, this.callId, required this.otherUserId, required this.name, required this.video, required this.incoming});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _local;
  final RTCVideoRenderer _localR = RTCVideoRenderer();
  final RTCVideoRenderer _remoteR = RTCVideoRenderer();
  int? _callId;
  String _status = 'Connecting...';
  bool _muted = false;
  bool _speaker = false;
  bool _camOn = true;
  bool _remoteSet = false;
  bool _finished = false;
  bool _connected = false;
  int _lastCand = 0;
  int _secs = 0;
  Timer? _poll;
  Timer? _ticker;
  final List<Map<String, dynamic>> _pendingLocal = [];
  final List<RTCIceCandidate> _pendingRemote = [];

  @override
  void initState() {
    super.initState();
    CallWatcher.inCall = true;
    _speaker = widget.video;
    _start();
  }

  Future<void> _start() async {
    try {
      await _localR.initialize();
      await _remoteR.initialize();
      final ice = await Api.get('calls/ice');
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.video ? {'facingMode': 'user'} : false,
      });
      _localR.srcObject = _local;
      final pc = await createPeerConnection({'iceServers': ice['ice_servers'], 'sdpSemantics': 'unified-plan'});
      _pc = pc;
      for (final t in _local!.getTracks()) {
        await pc.addTrack(t, _local!);
      }
      pc.onIceCandidate = (c) {
        if (c.candidate == null) return;
        final m = {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex};
        if (_callId == null) {
          _pendingLocal.add(m);
        } else {
          _sendCandidate(m);
        }
      };
      pc.onTrack = (e) {
        if (e.streams.isNotEmpty) {
          _remoteR.srcObject = e.streams[0];
          if (mounted) setState(() {});
        }
      };
      pc.onConnectionState = (s) {
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onConnected();
        } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _finish('The call could not connect. Please try again.', tellServer: true);
        }
      };
      await Helper.setSpeakerphoneOn(_speaker);

      if (widget.incoming) {
        _callId = widget.callId;
        final c = await Api.get('calls/$_callId');
        final o = jsonDecode(c['offer'] as String) as Map<String, dynamic>;
        await pc.setRemoteDescription(RTCSessionDescription(o['sdp'] as String, o['type'] as String));
        _remoteSet = true;
        final ans = await pc.createAnswer();
        await pc.setLocalDescription(ans);
        await Api.post('calls/$_callId/answer', {'answer': jsonEncode({'sdp': ans.sdp, 'type': ans.type})});
        _setStatus('Connecting...');
      } else {
        final offer = await pc.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': widget.video});
        await pc.setLocalDescription(offer);
        final r = await Api.post('calls', {
          'user_id': widget.otherUserId,
          'call_type': widget.video ? 'video' : 'audio',
          'offer': jsonEncode({'sdp': offer.sdp, 'type': offer.type}),
        });
        _callId = r['id'] as int;
        _setStatus('Ringing...');
      }
      for (final m in _pendingLocal) {
        _sendCandidate(m);
      }
      _pendingLocal.clear();
      _poll = Timer.periodic(const Duration(milliseconds: 1200), (_) => _tick());
    } on ApiException catch (e) {
      _finish(e.message, tellServer: false);
    } catch (_) {
      _finish('Could not start the call. Please allow microphone${widget.video ? ' and camera' : ''} permission and try again.', tellServer: true);
    }
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  void _onConnected() {
    if (_connected) return;
    _connected = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _secs++;
      if (mounted) setState(() => _status = _fmt(_secs));
    });
    if (mounted) setState(() => _status = '00:00');
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _sendCandidate(Map<String, dynamic> m) async {
    try {
      await Api.post('calls/$_callId/candidates', {'candidate': jsonEncode(m)});
    } catch (_) {}
  }

  bool _ticking = false;

  Future<void> _tick() async {
    if (_ticking || _finished || _callId == null) return;
    _ticking = true;
    try {
      final pc = _pc;
      if (pc == null) return;
      if (!widget.incoming && !_remoteSet) {
        final c = await Api.get('calls/$_callId');
        final st = c['status'] as String;
        if (_endedStates.contains(st)) {
          _finish(_endText(st), tellServer: false);
          return;
        }
        if (c['answer'] != null) {
          final a = jsonDecode(c['answer'] as String) as Map<String, dynamic>;
          await pc.setRemoteDescription(RTCSessionDescription(a['sdp'] as String, a['type'] as String));
          _remoteSet = true;
          _setStatus('Connecting...');
        }
      }
      final d = await Api.get('calls/$_callId/candidates', query: {'after_id': '$_lastCand'});
      for (final it in asList(d['items'])) {
        _lastCand = it['id'] as int;
        final m = jsonDecode(it['candidate'] as String) as Map<String, dynamic>;
        final cand = RTCIceCandidate(m['candidate'] as String?, m['sdpMid'] as String?, m['sdpMLineIndex'] as int?);
        if (_remoteSet) {
          await pc.addCandidate(cand);
        } else {
          _pendingRemote.add(cand);
        }
      }
      if (_remoteSet && _pendingRemote.isNotEmpty) {
        for (final c in _pendingRemote) {
          await pc.addCandidate(c);
        }
        _pendingRemote.clear();
      }
      final st = d['status'] as String;
      if (_endedStates.contains(st)) {
        _finish(_endText(st), tellServer: false);
      }
    } catch (_) {
      // a short network problem: the next tick tries again
    } finally {
      _ticking = false;
    }
  }

  String _endText(String st) {
    switch (st) {
      case 'declined':
        return '${widget.name} declined the call.';
      case 'missed':
        return '${widget.name} did not answer.';
      case 'cancelled':
        return 'Call cancelled.';
      default:
        return 'Call ended.';
    }
  }

  Future<void> _finish(String message, {required bool tellServer}) async {
    if (_finished) return;
    _finished = true;
    _poll?.cancel();
    _ticker?.cancel();
    if (tellServer && _callId != null) {
      try {
        await Api.post('calls/$_callId/end', {});
      } catch (_) {}
    }
    try {
      for (final t in _local?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
      await _pc?.close();
    } catch (_) {}
    CallWatcher.inCall = false;
    ChatBadge.refresh();
    if (!mounted) return;
    toast(context, message);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ticker?.cancel();
    _localR.dispose();
    _remoteR.dispose();
    CallWatcher.inCall = false;
    super.dispose();
  }

  void _toggleMute() {
    _muted = !_muted;
    for (final t in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !_muted;
    }
    setState(() {});
  }

  void _toggleSpeaker() {
    _speaker = !_speaker;
    Helper.setSpeakerphoneOn(_speaker);
    setState(() {});
  }

  void _toggleCam() {
    _camOn = !_camOn;
    for (final t in _local?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = _camOn;
    }
    setState(() {});
  }

  void _switchCam() {
    final v = _local?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (v.isNotEmpty) Helper.switchCamera(v.first);
  }

  Widget _btn(IconData icon, VoidCallback onTap, {bool on = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CircleAvatar(
        radius: 28,
        backgroundColor: color ?? (on ? Colors.white : Colors.white24),
        child: IconButton(icon: Icon(icon, color: color != null ? Colors.white : (on ? Colors.black : Colors.white)), onPressed: onTap),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showRemoteVideo = widget.video && _remoteR.srcObject != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish('Call ended.', tellServer: true);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B3B37),
        body: SafeArea(
          child: Stack(children: [
            if (showRemoteVideo) Positioned.fill(child: RTCVideoView(_remoteR, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
            if (!showRemoteVideo)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircleAvatar(radius: 54, child: Icon(Icons.person, size: 60)),
                  const SizedBox(height: 18),
                  Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ]),
              ),
            if (showRemoteVideo)
              Positioned(
                top: 12,
                left: 16,
                child: Text('${widget.name}  •  $_status', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 6, color: Colors.black)])),
              ),
            if (widget.video && _local != null)
              Positioned(
                top: 12,
                right: 12,
                width: 96,
                height: 140,
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: RTCVideoView(_localR, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _btn(_muted ? Icons.mic_off : Icons.mic, _toggleMute, on: _muted),
                _btn(_speaker ? Icons.volume_up : Icons.volume_down, _toggleSpeaker, on: _speaker),
                if (widget.video) _btn(_camOn ? Icons.videocam : Icons.videocam_off, _toggleCam, on: !_camOn),
                if (widget.video) _btn(Icons.cameraswitch, _switchCam),
                _btn(Icons.call_end, () => _finish('Call ended.', tellServer: true), color: Colors.red),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The "Calls" tab: history, missed calls in red, tap the icons to call back.
class CallsPage extends StatefulWidget {
  const CallsPage({super.key});
  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<Map<String, dynamic>> items = [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('calls');
      if (!mounted) return;
      setState(() {
        items = asList(d['items']);
        error = null;
        loading = false;
      });
      if ((d['missed_unseen'] ?? 0) > 0) {
        await Api.post('calls/seen', {});
        ChatBadge.refresh();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  String _label(Map<String, dynamic> c) {
    final dir = c['direction'] == 'out' ? 'Outgoing' : 'Incoming';
    switch (c['status']) {
      case 'missed':
        return c['direction'] == 'out' ? 'Not answered' : 'Missed';
      case 'declined':
        return c['direction'] == 'out' ? 'Declined' : 'You declined';
      case 'cancelled':
        return 'Cancelled';
      case 'ended':
        final s = (c['duration_seconds'] ?? 0) as int;
        return '$dir  •  ${s ~/ 60}m ${s % 60}s';
      default:
        return dir;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (items.isEmpty && error == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No calls yet. Open a chat with a connection and tap the call icon.', textAlign: TextAlign.center))),
        ...items.map((c) {
          final o = Map<String, dynamic>.from(c['other'] as Map);
          final missed = c['status'] == 'missed' && c['direction'] == 'in';
          return ListTile(
            leading: Icon(c['direction'] == 'out' ? Icons.call_made : Icons.call_received, color: missed ? Colors.red : Colors.green),
            title: Text(o['name'].toString(), style: TextStyle(color: missed ? Colors.red : null, fontWeight: FontWeight.w600)),
            subtitle: Text('${_label(c)}  •  ${c['type']}\n${fmtDate(c['created_at'] as String?)}'),
            isThreeLine: true,
            trailing: o['id'] == 0
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.call), onPressed: () => startCall(context, o['id'] as int, o['name'].toString(), false)),
                    IconButton(icon: const Icon(Icons.videocam), onPressed: () => startCall(context, o['id'] as int, o['name'].toString(), true)),
                  ]),
          );
        }),
      ]),
    );
  }
}
