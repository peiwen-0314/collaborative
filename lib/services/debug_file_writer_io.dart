import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// Non-web implementation - see `debugWriteHereResponse`'s doc (this
/// function's signature is shared with debug_file_writer_stub.dart, the
/// web build's no-op version) in here_transit_service.dart for why this
/// exists: a raw HERE API response dumped to a local file, checkable
/// one-to-one against what a RideOption card shows on screen, since
/// console output truncates/scrolls away long JSON. Always overwrites
/// the same `debug_here_responses/<tag>_last.json` file - written
/// relative to the app's current working directory, which for
/// `flutter run` on Windows desktop is the project root. Never allowed
/// to affect the real search - any failure (no write permission, disk
/// full, ...) is silently ignored.
void debugWriteHereResponse(String tag, Map<String, dynamic> body) {
  try {
    final dir = Directory('debug_here_responses');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/${tag}_last.json');
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(body));
    debugPrint('[$tag] raw response written to ${file.absolute.path}');
  } catch (error) {
    debugPrint('[$tag] could not write debug response file: $error');
  }
}
