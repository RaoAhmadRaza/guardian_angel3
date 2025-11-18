import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorage {
  static Future<String> saveFile(File file, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/$filename';
    final newFile = await file.copy(destPath);
    return newFile.path;
  }

  static Future<File> loadFile(String path) async {
    return File(path);
  }

  static Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<String> createUniqueFileName(String prefix, String ext) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$ts.$ext';
  }
}
