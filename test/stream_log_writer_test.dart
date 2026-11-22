import 'dart:io';

import 'package:bluecherry_client/utils/logging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('g2w_log_test_');
    supportDir = dir;
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File logFile(String name) => File('${dir.path}/logs/$name.txt');

  test('a burst of lines becomes a single bounded write', () async {
    final writer = StreamLogWriter.forStream('Burst (10.0.0.1)');
    for (var i = 0; i < 5000; i++) {
      writer.add('warn | ffmpeg/video: line $i');
    }
    expect(writer.pendingLines.length, StreamLogWriter.maxLinesPerFlush);
    await writer.flush();

    final lines = logFile('Burst (10.0.0.1)').readAsLinesSync();
    expect(lines.length, StreamLogWriter.maxLinesPerFlush + 1);
    expect(lines.last, contains('more lines dropped'));
    expect(writer.pendingLines, isEmpty);
  });

  test('identical consecutive messages are collapsed', () async {
    final writer = StreamLogWriter.forStream('Repeat (10.0.0.1)');
    for (var i = 0; i < 1000; i++) {
      writer.add('v | vo/libmpv: mpv_render_context_render() not being called');
    }
    await writer.flush();

    final lines = logFile('Repeat (10.0.0.1)').readAsLinesSync();
    expect(lines.length, 2);
    expect(lines.last, contains('repeated 999 more times'));
  });

  test('credentials never reach the file', () async {
    final writer = StreamLogWriter.forStream('Secrets (10.0.0.1)');
    writer
      ..add('v | ffmpeg: Opening rtsp://Admin:p%40ss@10.0.0.1:7002/live/7')
      ..add(
        'v | cplayer: Set property: http-header-fields='
        '["cookie: bluecherrydvr=abc123; path=/",'
        '"authorization: Basic QWRtaW46c2VjcmV0"] -> 1',
      )
      ..add('https://10.0.0.1:7001/hls/7/0/playlist.m3u8?authtoken=deadbeef');
    await writer.flush();

    final content = logFile('Secrets (10.0.0.1)').readAsStringSync();
    expect(content, isNot(contains('p%40ss')));
    expect(content, isNot(contains('QWRtaW46c2VjcmV0')));
    expect(content, isNot(contains('abc123')));
    expect(content, isNot(contains('deadbeef')));
    expect(content, contains('rtsp://Admin:***@10.0.0.1:7002/live/7'));
  });

  test('the file is rotated instead of growing without limit', () async {
    final file = logFile('Rotate (10.0.0.1)')..createSync(recursive: true);
    file.writeAsBytesSync(List.filled(kMaxStreamLogSize + 10, 0x61));
    final writer = StreamLogWriter.forStream('Rotate (10.0.0.1)')..add('new');
    await writer.flush();

    expect(File('${file.path}.1').existsSync(), isTrue);
    expect(file.lengthSync(), lessThan(1024));
  });

  test('legacy logs are purged once', () async {
    final legacy = logFile('Old')..createSync(recursive: true);
    legacy.writeAsStringSync('authorization: Basic QWRtaW46c2VjcmV0');
    final main = File('${dir.path}/logs.txt')..writeAsStringSync('old');

    await purgeLegacyLogs();
    expect(legacy.existsSync(), isFalse);
    expect(main.existsSync(), isFalse);

    // A second run must not touch the new files.
    legacy.writeAsStringSync('fresh');
    await purgeLegacyLogs();
    expect(legacy.existsSync(), isTrue);
  });

  test('unsafe characters are removed from the file name', () async {
    final writer = StreamLogWriter.forStream('Portaria 1/2: "A" (10.0.0.1)');
    expect(writer.name, isNot(contains('/')));
    expect(writer.name, isNot(contains('"')));
    writer.add('x');
    await writer.flush();
    expect(logFile(writer.name).existsSync(), isTrue);
  });
}
