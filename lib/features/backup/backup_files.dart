import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backup_repository.dart';

final backupFilesProvider = Provider<BackupFiles>((ref) => NativeBackupFiles());

abstract class BackupFiles {
  Future<bool> save(Uint8List bytes);
  Future<Uint8List?> pick();
}

class NativeBackupFiles implements BackupFiles {
  @override
  Future<bool> save(Uint8List bytes) async {
    final date = DateTime.now().toLocal().toIso8601String().split('T').first;
    return await FilePicker.saveFile(
          fileName: 'world-manager-$date.json',
          bytes: bytes,
          mimeType: 'application/json',
          dialogTitle: 'Save World Manager backup',
        ) !=
        null;
  }

  @override
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose World Manager backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    if ((await file.length() ?? 0) > maxBackupBytes) {
      throw const FormatException('Backup exceeds the 20 MB limit.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > maxBackupBytes) {
        throw const FormatException('Backup exceeds the 20 MB limit.');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }
}
