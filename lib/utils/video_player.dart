/*
 * This file is a part of Bluecherry Client (https://github.com/bluecherrydvr/unity).
 *
 * Copyright 2022 Bluecherry, LLC
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:bluecherry_client/api/api.dart';
import 'package:bluecherry_client/models/device.dart';
import 'package:bluecherry_client/models/event.dart';
import 'package:bluecherry_client/providers/settings_provider.dart';
import 'package:bluecherry_client/utils/logging.dart';
import 'package:bluecherry_client/utils/sanitize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:unity_video_player/unity_video_player.dart';

class UnityPlayers with ChangeNotifier {
  UnityPlayers._() {
    createTimer();
  }

  static final instance = UnityPlayers._();

  /// Instances of video players corresponding to a particular [Device].
  ///
  /// This avoids redundantly creating new video player instance if a [Device]
  /// is already present in the camera grid on the screen or allows to use
  /// existing instance when switching tab (if common camera [Device] tile exists).
  static final players = <String, UnityVideoPlayer>{};

  /// Devices that should be reloaded at every [reloadTime] interval.
  static final _reloadable = <String>{};

  static Timer? _reloadTimer;
  static void createTimer() {
    UnityPlayers._reloadTimer?.cancel();
    UnityPlayers._reloadTimer = null;
    if (SettingsProvider.instance.kRefreshRate.value > Duration.zero) {
      UnityPlayers._reloadTimer = Timer.periodic(
        SettingsProvider.instance.kRefreshRate.value,
        (_) => reloadDevices(),
      );
    }
  }

  /// Reloads all devices that are marked as reloadable.
  static Future<void> reloadDevices() async {
    if (_reloadable.isEmpty) return;
    // Never print the set itself: it holds stream URLs with credentials,
    // and stdout goes to the system journal.
    debugPrint('Reloading ${_reloadable.length} devices');
    for (final player in players.entries.where(
      (entry) => _reloadable.contains(entry.key),
    )) {
      // reload each device at once
      await reloadDevice(Device.fromUUID(player.key)!);
    }
  }

  /// Whether the given [Device] is reloadable.
  static bool isReloadable(String deviceUUID) =>
      _reloadable.contains(deviceUUID);

  /// Helper method to create a video player with required configuration for a [Device].
  static UnityVideoPlayer forDevice(
    Device device, [
    VoidCallback? onSetSource,
  ]) {
    SettingsProvider settings() => SettingsProvider.instance;
    late UnityVideoPlayer controller;

    // [force] reopens the stream even when the URL did not change. It is what
    // the stall watchdog needs: an RTSP URL is always the same, so without
    // it a "reload" of a frozen stream was silently ignored.
    Future<void> setSource({bool force = false}) async {
      if (device.url != null) {
        debugPrint('Initializing ${sanitizeSensitiveData(device.url ?? '')}');
        await controller.setDataSource(device.url!, force: force);
      } else {
        var streamingType =
            device.preferredStreamingType ??
            device.server.additionalSettings.preferredStreamingType ??
            settings().kStreamingType.value;
        if (kIsWeb && streamingType == StreamingType.rtsp) {
          streamingType = StreamingType.hls;
        }
        final (
          String source,
          Future<String> fallback,
        ) = switch (streamingType) {
          StreamingType.rtsp => (device.rtspURL, device.getHLSUrl()),
          StreamingType.hls => (
            await device.getHLSUrl(),
            Future.value(device.rtspURL),
          ),
          StreamingType.mjpeg => (device.mjpegURL, Future.value(device.hlsURL)),
        };
        debugPrint('Initializing ${sanitizeSensitiveData(source)}');
        controller.fallbackUrl = fallback;
        await controller.setDataSource(
          source,
          force: force,
          headers: {
            if (device.server.cookie != null)
              API.cookieHeader: device.server.cookie!,
            ...device.server.headers,
          },
        );

        _reloadable.add(source);
      }
      onSetSource?.call();
    }

    controller =
        UnityVideoPlayer.create(
            quality:
                (device.server.additionalSettings.renderingQuality ??
                        settings().kRenderingQuality.value)
                    .playerQuality,
            onReload: () {
              if (settings().kReloadTimedOutStreams.value) {
                // The HLS playlist URL carries a session token: asking for
                // the source again also renews it.
                setSource(force: true).catchError((error, stack) {
                  debugPrint('Failed to reload ${device.name}: $error');
                });
              }
            },
            title: device.name,
            matrixType: device.matrixType ?? settings().kMatrixSize.value,
            softwareZoom: settings().kSoftwareZooming.value,
            onLog: (message) {
              logStreamToFile(
                device.url ?? '${device.name} (${device.server.ip})',
                message,
              );
            },
          )
          ..setVolume(device.volume)
          ..setSpeed(1.0)
          ..volumeStream.listen((volume) {
            device.volume = volume;
          });

    setSource();

    controller.onError.listen((error) {
      writeLogToFile(
        'An error ocurred when playing a video (${controller.dataSource}): $error\n',
      );
      logStreamToFile(
        device.url ?? '${device.name} (${device.server.ip})',
        error,
      );
    });

    return controller;
  }

  static UnityVideoPlayer forEvent(Event event) {
    SettingsProvider settings() => SettingsProvider.instance;

    final controller =
        UnityVideoPlayer.create(
            quality: settings().kRenderingQuality.value.playerQuality,
            enableCache: true,
            title: event.title,
            matrixType: settings().kMatrixSize.value,
            softwareZoom: settings().kSoftwareZooming.value,
            onLog: (message) {
              logStreamToFile(
                event.mediaURL == null
                    ? 'Event ${event.title} (${event.id})'
                    : event.mediaPath,
                message,
              );
            },
          )
          ..setDataSource(
            event.mediaPath,
            headers: {
              if (event.server.cookie != null)
                API.cookieHeader: event.server.cookie!,
              ...event.server.headers,
            },
          )
          ..setVolume(1.0)
          ..setSpeed(1.0);

    controller.onError.listen((error) {
      writeLogToFile(
        'An error ocurred when playing an event video (${controller.dataSource}): $error\n',
      );
      logStreamToFile(
        event.mediaURL == null
            ? 'Event ${event.title} (${event.id})'
            : event.mediaPath,
        error,
      );
    });

    return controller;
  }

  static Future<void> initializeDevices(List<Device> devices) async {
    await Future.microtask(() async {
      for (final device in devices) {
        if (players.containsKey(device.uuid)) continue;
        players[device.uuid] = forDevice(device);
        // Players are created progressively (see the delay below) and some
        // callers do not await this method, so notify as each player becomes
        // available. Otherwise tiles built before their player exists never
        // rebuild and stay empty until a manual reload.
        instance.notifyListeners();
        await Future.delayed(const Duration(milliseconds: 350));
      }
    });
  }

  /// Release the video player for the given [Device].
  static Future<void> releaseDevice(String deviceUUID) async {
    // Take the player out of the map before the (asynchronous) dispose, so
    // nobody else can pick up, or dispose again, a player that is going away.
    final player = players.remove(deviceUUID);
    debugPrint('Releasing device $deviceUUID. $player');
    _reloadable.remove(deviceUUID);
    try {
      await player?.dispose();
    } catch (error, stack) {
      handleError(error, stack, 'Error releasing video player');
    }
    instance.notifyListeners();
  }

  /// Reloads in progress, by device.
  static final _reloads = <String, Future<void>>{};

  /// Reload the video player for the given [Device].
  ///
  /// Reloads of the same device are not allowed to overlap: they run one
  /// after the other. They are asked
  /// for from several places (window back in foreground, server refresh,
  /// the reload button) and two of them running together both waited for the
  /// old player to be disposed and then each created a new one: the second
  /// replaced the first in [players], which was left running forever with
  /// nobody to render or dispose it - decoding video in the background until
  /// the app was closed.
  static Future<void> reloadDevice(Device device) {
    // Queue behind the reload in progress instead of joining it: a later
    // request may carry a changed [device] (another URL or streaming type).
    final previous = _reloads[device.uuid];
    late final Future<void> current;
    current = () async {
      try {
        await previous;
      } catch (_) {}
      try {
        await releaseDevice(device.uuid);
        // Something else (a layout being opened) may have created the player
        // while the old one was being disposed: keep that one.
        players[device.uuid] ??= forDevice(device);
        instance.notifyListeners();
      } finally {
        if (identical(_reloads[device.uuid], current)) {
          _reloads.remove(device.uuid);
        }
      }
    }();
    return _reloads[device.uuid] = current;
  }

  /// Reload all video players, one at a time.
  ///
  /// [onlyIfTimedOut], if true, the device will only be reloaded if it's timed out
  static Future<void> reloadAll({bool onlyIfTimedOut = false}) async {
    // Copy: reloading changes the map.
    for (final entry in players.entries.toList()) {
      final player = entry.value;
      if (onlyIfTimedOut && !player.isImageOld) continue;
      final device = Device.fromUUID(entry.key);
      // One after the other. Tearing every player down at the same moment
      // is what froze the window.
      if (device != null) await reloadDevice(device);
    }
  }

  /// Opens a fullscreen video player for the given [Device].
  ///
  /// If there is not a video player instance for the given [Device], it will
  /// be created and released when the fullscreen player is closed.
  static Future<void> openFullscreen(
    BuildContext context,
    Device device, {
    bool ptzEnabled = false,
  }) async {
    var player = UnityPlayers.players[device.uuid];
    final isLocalController = player == null;
    if (isLocalController) player = UnityPlayers.forDevice(device);

    await Navigator.of(context).pushNamed(
      '/fullscreen',
      arguments: {'device': device, 'player': player, 'ptzEnabled': ptzEnabled},
    );
    if (isLocalController) await player.dispose();
  }

  static Future<void> playAll() async {
    for (final player in players.values) {
      if (!player.isPlaying) {
        player.seekTo(player.duration);
        await player.start();
      }
    }
    return Future.value();
  }

  static Future<void> pauseAll() {
    for (final player in players.values) {
      if (player.isPlaying) player.pause();
    }
    return Future.value();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    super.dispose();
  }
}
