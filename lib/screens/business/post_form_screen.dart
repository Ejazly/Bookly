import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../services/storage_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';

enum _Media { foto, video, texto }

/// Crear una publicación nueva: texto con una foto o un video (opcional).
///
/// La foto se guarda dentro de la publicación (Firestore). El video, como es
/// mucho más pesado, se sube a Firebase Storage y la publicación guarda su
/// dirección.
class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, required this.business});

  final Business business;

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  _Media _media = _Media.foto;
  String? _image;
  PickedVideo? _video;
  bool _saving = false;
  double? _progress; // subida del video, de 0 a 1

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final v = await StorageService.pickVideo();
      if (v != null) setState(() => _video = v);
    } on VideoTooLargeException catch (e) {
      if (mounted) {
        showMessage(context,
            'El video pesa ${e.megabytes.toStringAsFixed(0)} MB. El máximo es ${StorageService.maxMegabytes} MB.');
      }
    } on VideoFormatException {
      if (mounted) showMessage(context, 'Ese archivo no es un video compatible (MP4, MOV o WEBM).');
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo abrir el video: $e');
    }
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_media == _Media.video && _video == null) {
      showMessage(context, 'Elige el video que quieres publicar.');
      return;
    }
    final b = widget.business;
    final uid = AppScope.read(context).user?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    String? videoPath;
    try {
      String? videoUrl;
      final video = _media == _Media.video ? _video : null;
      if (video != null) {
        setState(() => _progress = 0);
        final up = await StorageService.uploadPostVideo(
          uid: uid,
          video: video,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        videoUrl = up.url;
        videoPath = up.path;
      }
      await Database.instance.addPost(Post(
        id: '',
        businessId: b.id,
        businessName: b.name,
        category: b.category,
        text: _text.text.trim(),
        imageBase64: _media == _Media.foto ? _image : null,
        videoUrl: videoUrl,
        videoPath: videoPath,
      ));
      if (!mounted) return;
      showMessage(context, '¡Publicado!');
      Navigator.of(context).pop();
    } catch (e) {
      // Si el video sí se subió pero la publicación falló, se borra el video.
      await StorageService.deleteVideo(videoPath).catchError((_) {});
      if (mounted) showMessage(context, 'No se pudo publicar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  Widget _mediaSelector() {
    Widget option(_Media m, IconData icon, String label) {
      final selected = _media == m;
      return Expanded(
        child: GestureDetector(
          onTap: _saving ? null : () => setState(() => _media = m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.teal : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.teal : AppColors.gray),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? Colors.white : AppColors.teal),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(_Media.foto, Icons.photo_outlined, 'Foto'),
        const SizedBox(width: 8),
        option(_Media.video, Icons.videocam_outlined, 'Video'),
        const SizedBox(width: 8),
        option(_Media.texto, Icons.notes_rounded, 'Solo texto'),
      ],
    );
  }

  Widget _videoBox() {
    final v = _video;
    return InkWell(
      onTap: _saving ? null : _pickVideo,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: v == null
              ? null
              : const LinearGradient(
                  colors: [AppColors.teal, AppColors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: v == null ? AppColors.mist : null,
          border: v == null ? Border.all(color: AppColors.sky, width: 2) : null,
        ),
        child: v == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 44, color: AppColors.teal),
                  SizedBox(height: 8),
                  Text('Elegir video de la galería',
                      style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Máximo ${StorageService.maxMegabytes} MB y 90 segundos',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 44),
                  const SizedBox(height: 8),
                  Text('Video listo · ${v.megabytes.toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (!_saving)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _pickVideo,
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Cambiar'),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _video = null),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Quitar'),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            _mediaSelector(),
            const SizedBox(height: 14),
            switch (_media) {
              _Media.foto => ImagePickerBox(
                  value: _image,
                  height: 220,
                  label: 'Agregar foto',
                  onChanged: (v) => setState(() => _image = v),
                ),
              _Media.video => _videoBox(),
              _Media.texto => const SizedBox.shrink(),
            },
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.mist,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text('Subiendo video… ${(progress * 100).toStringAsFixed(0)} %',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _text,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration('¿Qué quieres contarle a tus clientes?'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el texto' : null,
            ),
            const SizedBox(height: 4),
            const Text(
              'Idea: anuncia una promoción, muestra un trabajo reciente en video o avisa de un horario especial.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Publicar', loading: _saving, onPressed: _publish),
          ],
        ),
      ),
    );
  }
}
