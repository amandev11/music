import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../backend/backend.dart';
import '../core/models.dart';
import '../ui/widgets/playlists.dart';

/// Siri and Shortcuts: "play <song> on Music", pause, resume, next, previous, like, liked songs, playlists,
/// "what's playing". The native App Intents hand over one JSON command; this runs it.
class SiriBridge with WidgetsBindingObserver {
  SiriBridge(this._backend) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'siri' && call.arguments is String) {
        unawaited(_run(call.arguments as String));
        return true;
      }
      return null;
    });
    WidgetsBinding.instance.addObserver(this);
    _backend.snapshot.addListener(_publishNow);
    unawaited(_take());
    // A cold start through Siri can finish launching a moment after the intent ran.
    Timer(const Duration(seconds: 2), () => unawaited(_take()));
  }

  static const _ch = MethodChannel('aurora/pcm');
  final Backend _backend;
  String? _last;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _nowShown;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_take());
  }

  /// Keeps "what's playing" readable by Siri even when the app is in the background.
  void _publishNow() {
    final t = _backend.snapshot.value.current;
    final text = t == null ? '' : '${t.title}${t.artist.isEmpty ? '' : ' by ${t.artist}'}';
    if (text == _nowShown) return;
    _nowShown = text;
    unawaited(_ch.invokeMethod<void>('siriNow', text).catchError((_) {}));
  }

  Future<void> _take() async {
    try {
      final q = await _ch.invokeMethod<String>('takeSiri');
      if (q != null && q.trim().isNotEmpty) await _run(q);
    } catch (_) {}
  }

  Future<void> _run(String raw) async {
    // The same command can arrive by notification and by the stored copy: run it once.
    if (raw == _last && DateTime.now().difference(_lastAt) < const Duration(seconds: 4)) return;
    _last = raw;
    _lastAt = DateTime.now();
    String cmd = 'play', q = raw;
    try {
      final m = jsonDecode(raw) as Map;
      cmd = '${m['cmd']}';
      q = '${m['q'] ?? ''}'.trim();
    } catch (_) {}
    try {
      final playing = _backend.snapshot.value.isPlaying;
      switch (cmd) {
        case 'pause':
          if (playing) await _backend.toggle();
        case 'resume':
          if (!playing) await _backend.toggle();
        case 'next':
          await _backend.next();
        case 'previous':
          await _backend.previous();
        case 'like':
          final t = _backend.snapshot.value.current;
          if (t != null && !UserPlaylists.isLiked(t.mediaId)) UserPlaylists.toggleLike(t);
        case 'liked':
          await _playPlaylist(UserPlaylists.likedId, shuffle: false);
        case 'shuffle':
          await _playPlaylist(UserPlaylists.likedId, shuffle: true);
        case 'playlist':
          final want = q.toLowerCase();
          final all = UserPlaylists.all();
          final hit = all.where((p) => '${p['name']}'.toLowerCase() == want).followedBy(all.where((p) => '${p['name']}'.toLowerCase().contains(want)));
          if (hit.isNotEmpty) {
            await _playPlaylist('${hit.first['id']}', shuffle: false);
          } else {
            await _playQuery(q);
          }
        default:
          await _playQuery(q);
      }
    } catch (e) {
      debugPrint('Siri command failed: $e');
    }
  }

  Future<void> _playPlaylist(String id, {required bool shuffle}) async {
    final p = UserPlaylists.all().firstWhere((p) => p['id'] == id, orElse: () => const {});
    final tracks = <Track>[for (final m in (p['tracks'] as List? ?? const [])) Track.fromMap(Map<String, dynamic>.from(m as Map))];
    if (tracks.isEmpty) return;
    await _backend.playTracks(tracks, 0, shuffle: shuffle);
  }

  Future<void> _playQuery(String q) async {
    if (q.isEmpty) return;
    var found = await _backend.searchLocal(q);
    // A title match in the library wins; otherwise search the catalogue.
    if (found.isEmpty) found = await _backend.searchRemote(q);
    if (found.isEmpty) return;
    await _backend.playTracks(found, 0);
  }
}
