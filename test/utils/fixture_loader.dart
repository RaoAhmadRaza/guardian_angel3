import 'dart:convert';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle; 

/// Loads a JSON fixture from `test/fixtures/`.
///
/// Tries `rootBundle` first (if configured via pubspec assets),
/// then falls back to reading from the filesystem.
Future<Map<String, dynamic>> loadJsonFixture(String name) async {
  final path = 'test/fixtures/' + name;

  // Try rootBundle first
  try {
    final data = await rootBundle.loadString(path);
    return json.decode(data) as Map<String, dynamic>;
  } catch (_) {
    // Fallback to direct file read
    final file = File(path);
    final data = await file.readAsString();
    return json.decode(data) as Map<String, dynamic>;
  }
}

/// Alternative API matching provided snippets.
/// Loads `test/fixtures/<name>.json` using rootBundle first, with a file fallback.
Future<Map<String, dynamic>> loadFixture(String name) async {
  final path = 'test/fixtures/$name.json';
  try {
    final data = await rootBundle.loadString(path);
    return convert.jsonDecode(data) as Map<String, dynamic>;
  } catch (_) {
    final file = File(path);
    final data = await file.readAsString();
    return convert.jsonDecode(data) as Map<String, dynamic>;
  }
}
