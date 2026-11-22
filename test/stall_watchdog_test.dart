import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_video_player/unity_video_player.dart';

/// A player with no backend: only the watchdog of the base class is tested.
class _FakePlayer extends UnityVideoPlayer {
  final position = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  final errors = StreamController<String>.broadcast();
  final fpsController = StreamController<double>.broadcast();

  String? source = 'rtsp://camera/live/1';
  int opened = 0;

  @override
  String? get dataSource => source;
  @override
  Stream<String> get onError => errors.stream;
  @override
  Duration get duration => Duration.zero;
  @override
  Stream<Duration> get onDurationUpdate => durationController.stream;
  @override
  Duration get currentPos => Duration.zero;
  @override
  Stream<Duration> get onCurrentPosUpdate => position.stream;
  @override
  bool get isBuffering => false;
  @override
  Stream<bool> get onBufferStateUpdate => const Stream.empty();
  @override
  Duration get currentBuffer => Duration.zero;
  @override
  Stream<Duration> get onBufferUpdate => const Stream.empty();
  @override
  bool get isPlaying => false; // what a backend reports after a failure
  @override
  Stream<bool> get onPlayingStateUpdate => const Stream.empty();
  @override
  double get fps => 0;
  @override
  Stream<double> get fpsStream => fpsController.stream;
  @override
  Future<String> getProperty(String propertyName) async => '';
  @override
  bool get isSeekable => false;
  @override
  Future<void> setDataSource(
    String url, {
    bool autoPlay = true,
    Map<String, String>? headers,
    bool force = false,
  }) async {
    if (!force && url == dataSource) return;
    source = url;
    opened++;
  }

  @override
  Future<void> setMultipleDataSource(
    Iterable<String> url, {
    bool autoPlay = true,
    Map<String, String>? headers,
  }) async {}
  @override
  Future<void> jumpToIndex(int index) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  double get volume => 0;
  @override
  Stream<double> get volumeStream => const Stream.empty();
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> setSize(Size size) async {}
  @override
  double get aspectRatio => 1;
  @override
  Future<void> start() async => pausedOnPurpose = false;
  @override
  Future<void> pause() async => pausedOnPurpose = true;
  @override
  Future<void> release() async {}
  @override
  Future<void> reset() async {}
}

void main() {
  late _FakePlayer player;
  late DateTime now;
  late int reloads;

  setUp(() {
    now = DateTime(2026, 11, 21, 12);
    reloads = 0;
    player =
        _FakePlayer()
          ..lateVideoBehavior = LateVideoBehavior.never
          ..onReload = () => reloads++;
    player.clock = () => now;
    player.onReady();
  });

  tearDown(() => player.dispose());

  void advance(Duration by) {
    now = now.add(by);
    player.checkStalled();
  }

  test('a moving stream is never reloaded', () async {
    for (var i = 0; i < 20; i++) {
      // A frame arrives shortly before each check of the watchdog.
      now = now.add(const Duration(seconds: 13));
      player.position.add(Duration(seconds: 14 * (i + 1)));
      await Future<void>.delayed(Duration.zero);
      advance(const Duration(seconds: 1));
    }
    expect(reloads, 0);
    expect(player.isImageOld, isFalse);
  });

  test('a frozen stream is flagged and then reopened', () async {
    player.position.add(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);

    advance(const Duration(seconds: 14));
    expect(player.isImageOld, isTrue);
    expect(reloads, 0);

    advance(const Duration(seconds: 14));
    advance(const Duration(seconds: 14));
    expect(reloads, 1, reason: 'reopened after 42 seconds without image');
  });

  test('keeps retrying, with growing spacing, while it is offline', () {
    // Never produced an image (server offline when the app started).
    for (var i = 0; i < 3 * 60 * 60 ~/ 14; i++) {
      advance(const Duration(seconds: 14));
    }
    // 3 hours offline: more than a handful of attempts, far from one per tick.
    expect(reloads, greaterThan(20));
    expect(reloads, lessThan(60));
  });

  test('an image resets the state', () async {
    for (var i = 0; i < 10; i++) {
      advance(const Duration(seconds: 14));
    }
    expect(reloads, greaterThan(0));

    player.position.add(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);
    expect(player.isImageOld, isFalse);
    expect(player.reloadAttempts, 0);
  });

  test('a stream paused on purpose is left alone', () async {
    await player.pause();
    for (var i = 0; i < 20; i++) {
      advance(const Duration(seconds: 14));
    }
    expect(reloads, 0);
  });

  test('recordings are not reloaded', () {
    player.source = 'https://server/media/request.php?id=1';
    for (var i = 0; i < 20; i++) {
      advance(const Duration(seconds: 14));
    }
    expect(reloads, 0);
  });

  test('stays quiet while the window is hidden', () {
    UnityVideoPlayerInterface.registerPlayer(player);
    addTearDown(() {
      UnityVideoPlayerInterface.setAppHidden(false);
      UnityVideoPlayerInterface.unregisterPlayer(player);
    });

    UnityVideoPlayerInterface.setAppHidden(true);
    for (var i = 0; i < 500; i++) {
      advance(const Duration(seconds: 14));
    }
    expect(reloads, 0, reason: 'nothing is asked from a hidden player');

    // Visible again: the hidden time does not count, a dead stream gets one
    // short grace period and is then reopened in place.
    UnityVideoPlayerInterface.setAppHidden(false);
    expect(reloads, 0);
    advance(const Duration(seconds: 13));
    expect(reloads, 0);
    advance(const Duration(seconds: 1));
    expect(reloads, 1);
  });

  test('a healthy stream is left alone when the window comes back', () async {
    UnityVideoPlayerInterface.registerPlayer(player);
    addTearDown(() {
      UnityVideoPlayerInterface.setAppHidden(false);
      UnityVideoPlayerInterface.unregisterPlayer(player);
    });

    UnityVideoPlayerInterface.setAppHidden(true);
    advance(const Duration(hours: 9));
    UnityVideoPlayerInterface.setAppHidden(false);
    for (var i = 0; i < 10; i++) {
      now = now.add(const Duration(seconds: 13));
      player.position.add(Duration(seconds: i + 1));
      await Future<void>.delayed(Duration.zero);
      advance(const Duration(seconds: 1));
    }
    expect(reloads, 0);
  });

  test('force reopens the same URL', () async {
    await player.setDataSource('rtsp://camera/live/1');
    expect(player.opened, 0);
    await player.setDataSource('rtsp://camera/live/1', force: true);
    expect(player.opened, 1);
  });
}
