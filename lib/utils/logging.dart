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
import 'dart:io';

import 'package:bluecherry_client/providers/server_provider.dart';
import 'package:bluecherry_client/utils/sanitize.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

late Directory supportDir;
Future<void> setupLogging() async {
  Logger.root.level = Level.ALL; // You can set the log level as needed.
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  if (!kIsWeb) {
    supportDir = await getApplicationSupportDirectory();
    await purgeLegacyLogs();
  }
}

void handleError(
  dynamic error,
  dynamic stackTrace, [
  String context = 'Uncaught error',
]) {
  // Errors may embed stream URLs containing cleartext credentials.
  final sanitizedContext = sanitizeSensitiveData(context);
  final sanitizedError = sanitizeSensitiveData('$error');
  debugPrint('$sanitizedContext: $sanitizedError');
  debugPrintStack(stackTrace: stackTrace, label: sanitizedContext);

  // Write the error information to a log file.
  writeErrorToFile(sanitizedError, stackTrace, sanitizedContext);
}

Future<File?> getLogFile() async {
  try {
    return File(path.join(supportDir.path, 'logs.txt'));
  } catch (e) {
    // debugPrint('Error getting log file: $e');
    return null;
  }
}

Future<void> writeErrorToFile(
  dynamic error,
  dynamic stackTrace, [
  String context = '',
]) async {
  if (kIsWeb) return;

  final time = DateTime.now().toIso8601String();
  final errorLog =
      '\n[$time]${sanitizeSensitiveData(context)}'
      '\n[$time]Error: ${sanitizeSensitiveData('$error')}\n'
      '[$time]Stack trace: $stackTrace';

  // Failing to persist an error must never raise another error: when the
  // process is out of file descriptors this would otherwise loop forever.
  try {
    final file = await getLogFile();
    if (file != null) await _rotateIfNeeded(file, kMaxMainLogSize);
    await file?.writeAsString(errorLog, mode: FileMode.append);
    Logger.root.log(Level.INFO, 'Wrote log file to "${file?.path}"');
  } catch (_) {}
  Logger.root.log(Level.SEVERE, errorLog);
}

Future<void> writeLogToFile(String text, {bool print = false}) async {
  // Redact credentials embedded in URLs (e.g. `user:password@host`), session
  // tokens and auth headers before persisting or printing anything.
  text = sanitizeSensitiveData(text);
  if (!kIsWeb) {
    final time = DateTime.now().toIso8601String();
    final file = await getLogFile();

    final credentials = ServersProvider.instance.servers.map((server) {
      return '${server.login}:${server.password}';
    });
    for (final credential in credentials) {
      text = text.replaceAll(credential, '****:****');
    }

    try {
      if (file != null) await _rotateIfNeeded(file, kMaxMainLogSize);
      await file?.writeAsString('\n[$time] $text', mode: FileMode.append);
    } catch (_) {}
    if (print) Logger.root.log(Level.INFO, 'Wrote log file to "${file?.path}"');
  }
  if (print) debugPrint(text);
}

/// Maximum size of the main `logs.txt` file before it is rotated.
const kMaxMainLogSize = 2 * 1024 * 1024;

/// Maximum size of each per-stream log file before it is rotated.
const kMaxStreamLogSize = 2 * 1024 * 1024;

/// Keeps one previous generation (`<name>.1`) and starts a fresh file once
/// [file] grows beyond [maxSize]. Files that grew far beyond the limit (logs
/// written by versions without rotation reached hundreds of megabytes) are
/// dropped instead of being kept as the previous generation.
Future<void> _rotateIfNeeded(File file, int maxSize) async {
  try {
    if (!await file.exists()) return;
    final length = await file.length();
    if (length < maxSize) return;
    final previous = File('${file.path}.1');
    if (await previous.exists()) await previous.delete();
    if (length > maxSize * 4) {
      await file.delete();
    } else {
      await file.rename(previous.path);
    }
  } catch (_) {
    // Rotation is best effort.
  }
}

/// Removes the log files written by versions that stored player output
/// verbatim, including the credentials of the server, and never rotated it.
///
/// Runs once: a marker file is left in the logs directory afterwards.
Future<void> purgeLegacyLogs() async {
  if (kIsWeb) return;
  try {
    final logsDir = Directory(path.join(supportDir.path, 'logs'));
    final marker = File(path.join(logsDir.path, '.sanitized-v1'));
    if (await marker.exists()) return;
    if (await logsDir.exists()) {
      await for (final entity in logsDir.list()) {
        if (entity is File) await entity.delete();
      }
    } else {
      await logsDir.create(recursive: true);
    }
    final mainLog = File(path.join(supportDir.path, 'logs.txt'));
    if (await mainLog.exists()) await mainLog.delete();
    await marker.writeAsString(DateTime.now().toIso8601String());
  } catch (error) {
    debugPrint('Could not purge legacy logs: $error');
  }
}

String _streamLogFileName(String streamUrl) {
  final streamUri = Uri.tryParse(streamUrl);
  String fileName;
  if (streamUri == null || streamUri.host.isEmpty) {
    fileName = streamUrl;
  } else {
    fileName =
        ''
        '${streamUri.host}-'
        '${streamUri.port}'
        '${streamUri.path.replaceAll('/', '-')}';
  }
  // The name may come from a camera name typed by the user.
  fileName = fileName.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '-').trim();
  if (fileName.isEmpty) fileName = 'stream';
  if (fileName.length > 120) fileName = fileName.substring(0, 120);
  return fileName;
}

Future<File> getLogFileForStream(String streamUrl) async {
  final file = File(
    path.join(supportDir.path, 'logs', '${_streamLogFileName(streamUrl)}.txt'),
  );

  if (!(await file.exists())) {
    await file.create(recursive: true);
  }

  return file;
}

/// Buffers the log lines of one stream and writes them with a single file
/// operation at a time.
///
/// The player can emit thousands of lines per minute (decoder warnings on a
/// broken stream, for instance). Writing each line with its own
/// `File.writeAsString` opens one file descriptor per line, all of them
/// concurrently; after a burst the process ran out of descriptors
/// (`errno = 24, Too many open files`) and nothing else could be opened -
/// sockets included.
class StreamLogWriter {
  StreamLogWriter._(this.name);

  static final _writers = <String, StreamLogWriter>{};

  factory StreamLogWriter.forStream(String streamUrl) {
    final name = _streamLogFileName(streamUrl);
    return _writers[name] ??= StreamLogWriter._(name);
  }

  /// How often the buffered lines are written to disk.
  static const flushInterval = Duration(seconds: 3);

  /// Lines accepted per [flushInterval]. Anything above is counted and
  /// dropped, so a noisy stream can not grow the buffer nor the file.
  static const maxLinesPerFlush = 60;

  final String name;
  final _buffer = <String>[];
  Timer? _timer;
  bool _flushing = false;
  int _dropped = 0;
  String? _lastLine;
  int _repeated = 0;

  @visibleForTesting
  List<String> get pendingLines => List.unmodifiable(_buffer);

  void add(String log) {
    final line = sanitizeSensitiveData(log).trimRight();
    if (line.isEmpty) return;

    // Collapse consecutive identical messages.
    if (line == _lastLine) {
      _repeated++;
      _schedule();
      return;
    }
    _closeRepetition();
    _lastLine = line;

    if (_buffer.length >= maxLinesPerFlush) {
      _dropped++;
    } else {
      _buffer.add('[${DateTime.now().toIso8601String()}] $line');
    }
    _schedule();
  }

  void _closeRepetition() {
    if (_repeated > 0) {
      _buffer.add('    (previous message repeated $_repeated more times)');
      _repeated = 0;
    }
  }

  void _schedule() {
    _timer ??= Timer(flushInterval, flush);
  }

  /// Writes the pending lines. Only one write per stream is ever in flight.
  Future<void> flush() async {
    _timer = null;
    if (_flushing) {
      _schedule();
      return;
    }
    _closeRepetition();
    _lastLine = null;
    if (_buffer.isEmpty && _dropped == 0) return;

    final lines = List<String>.of(_buffer);
    _buffer.clear();
    if (_dropped > 0) {
      lines.add('    ($_dropped more lines dropped: too many messages)');
      _dropped = 0;
    }

    _flushing = true;
    try {
      final file = File(path.join(supportDir.path, 'logs', '$name.txt'));
      await _rotateIfNeeded(file, kMaxStreamLogSize);
      if (!await file.exists()) await file.create(recursive: true);
      await file.writeAsString('${lines.join('\n')}\n', mode: FileMode.append);
    } catch (_) {
      // Logging is best effort: never surface (or log) a logging failure.
    } finally {
      _flushing = false;
    }
  }
}

Future<void> logStreamToFile(String streamUrl, String log) async {
  if (kIsWeb) return;
  StreamLogWriter.forStream(streamUrl).add(log);
}
