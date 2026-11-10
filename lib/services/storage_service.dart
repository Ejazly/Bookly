import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Video que se va a subir.
class PickedVideo {
  const PickedVideo({required this.bytes, required this.extension, required this.contentType});

  final Uint8List bytes;
  final String extension; // mp4, mov, webm, 3gp
  final String contentType; // video/mp4...

  double get megabytes => bytes.lengthInBytes / (1024 * 1024);
}

class VideoTooLargeException implements Exception {
  VideoTooLargeException(this.megabytes);
  final double megabytes;
}

class VideoFormatException implements Exception {}

/// Subida de videos de las publicaciones a Firebase Storage.
///
/// Los videos NO caben en Firestore (máximo 1 MB por documento), por eso se
/// guardan en Storage y en la publicación solo queda su dirección.
/// Las reglas de `storage.rules` solo dejan que cada negocio suba a su propia
/// carpeta, únicamente videos y de máximo 50 MB.
class StorageService {
  StorageService._();

  static const int maxMegabytes = 50;
  static const Duration maxDuration = Duration(seconds: 90);

  static const Map<String, String> _types = {
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
  };

  /// Abre la galería para elegir un video. null = la persona canceló.
  static Future<PickedVideo?> pickVideo() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxDuration,
    );
    if (file == null) return null;

    var ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
    if (!_types.containsKey(ext)) {
      // En web a veces el nombre no trae extensión: se usa el tipo del archivo.
      final mime = file.mimeType ?? '';
      ext = _types.entries
          .firstWhere((e) => e.value == mime, orElse: () => const MapEntry('', ''))
          .key;
    }
    if (ext.isEmpty) throw VideoFormatException();
    if (ext == 'm4v') ext = 'mp4';

    final size = await file.length();
    final mb = size / (1024 * 1024);
    if (mb > maxMegabytes) throw VideoTooLargeException(mb);

    final bytes = await file.readAsBytes();
    return PickedVideo(bytes: bytes, extension: ext, contentType: _types[ext]!);
  }

  /// Sube el video y regresa (dirección para verlo, ruta en Storage).
  /// [onProgress] recibe de 0.0 a 1.0.
  static Future<({String url, String path})> uploadPostVideo({
    required String uid,
    required PickedVideo video,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.${video.extension}';
    final ref = FirebaseStorage.instance.ref(path);
    final task = ref.putData(video.bytes, SettableMetadata(contentType: video.contentType));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    return (url: await ref.getDownloadURL(), path: path);
  }

  /// Borra un video (al eliminar la publicación). Si ya no existe no pasa nada.
  static Future<void> deleteVideo(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
