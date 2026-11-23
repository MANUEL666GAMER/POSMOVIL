import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/database_provider.dart';
import '../../settings/data/settings_repository.dart';

final driveBackupServiceProvider = Provider<DriveBackupService>((ref) {
  return DriveBackupService(ref);
});

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class DriveBackupService {
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  DriveBackupService(this._ref);

  Future<GoogleSignInAccount?> signIn() async {
    return await _googleSignIn.signIn();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  }

  /// Comprime la base de datos local y la sube a Google Drive (drive.appdata)
  Future<void> backupDatabase() async {
    final account = await getCurrentUser() ?? await signIn();
    if (account == null) throw Exception('No se inició sesión con Google');

    final authHeaders = await account.authHeaders;
    final driveApi = drive.DriveApi(_GoogleAuthClient(authHeaders));

    // 1. Localizar base de datos SQLite y comprimirla
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'pos_facil.sqlite'));
    if (!await dbFile.exists()) throw Exception('No se encontró la base de datos local');

    final rawBytes = await dbFile.readAsBytes();
    final compressedBytes = GZipCodec().encode(rawBytes);

    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final gzFile = File(p.join(tempDir.path, 'pos_facil_backup_$dateStr.sqlite.gz'));
    await gzFile.writeAsBytes(compressedBytes);

    // 2. Subir archivo a la carpeta privada appDataFolder
    final driveFile = drive.File()
      ..name = p.basename(gzFile.path)
      ..parents = ['appDataFolder'];

    final media = drive.Media(gzFile.openRead(), await gzFile.length());
    await driveApi.files.create(driveFile, uploadMedia: media);

    // 3. Conservar solo los últimos 7 respaldos
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, createdTime)',
    );

    final files = fileList.files ?? [];
    if (files.length > 7) {
      for (final oldFile in files.skip(7)) {
        if (oldFile.id != null) {
          await driveApi.files.delete(oldFile.id!);
        }
      }
    }

    // 4. Registrar fecha del último respaldo
    await _ref.read(settingsRepositoryProvider).saveSetting(
      'last_backup_at',
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
    );
  }

  /// Descarga el respaldo más reciente, reemplaza la BD y reinicia el provider
  Future<void> restoreLatestBackup() async {
    final account = await getCurrentUser() ?? await signIn();
    if (account == null) throw Exception('No se inició sesión con Google');

    final authHeaders = await account.authHeaders;
    final driveApi = drive.DriveApi(_GoogleAuthClient(authHeaders));

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
      pageSize: 1,
      $fields: 'files(id, name)',
    );

    final files = fileList.files ?? [];
    if (files.isEmpty || files.first.id == null) {
      throw Exception('No hay respaldos guardados en Google Drive');
    }

    // Descargar bytes comprimidos
    final media = await driveApi.files.get(
      files.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final List<int> compressedBytes = [];
    await for (final chunk in media.stream) {
      compressedBytes.addAll(chunk);
    }

    final decompressedBytes = GZipCodec().decode(compressedBytes);

    // Cerrar conexión actual de Drift antes de sobreescribir el archivo
    final db = _ref.read(databaseProvider);
    await db.close();

    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'pos_facil.sqlite'));
    await dbFile.writeAsBytes(decompressedBytes, flush: true);

    // Invalidar provider para reabrir la BD restaurada
    _ref.invalidate(databaseProvider);
  }
}