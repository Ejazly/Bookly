import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter, instantiateImageCodec;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

// Las imágenes de productos y publicaciones se guardan dentro de Firestore
// como texto (base64). Así no se necesita Firebase Storage, que hoy pide
// una cuenta con tarjeta. Por eso se comprimen antes de guardarlas.

/// Tamaño máximo del texto de la imagen (~600 KB). Firestore permite 1 MB por documento.
const int _maxBase64Length = 800000;

final Map<String, Uint8List> _decodedCache = {};

Uint8List? _decode(String data) {
  final cached = _decodedCache[data];
  if (cached != null) return cached;
  try {
    final bytes = base64Decode(data);
    if (_decodedCache.length > 60) _decodedCache.clear();
    _decodedCache[data] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// Abre la galería, comprime la foto y la regresa como texto base64.
/// Regresa null si la persona cancela. Lanza un [Exception] si es muy pesada.
///
/// [maxSize] es el ancho/alto máximo en píxeles: más chico = pesa menos.
Future<String?> pickImageAsBase64({double maxSize = 900, int quality = 70}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxSize,
    maxHeight: maxSize,
    imageQuality: quality,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final encoded = base64Encode(bytes);
  if (encoded.length > _maxBase64Length) {
    throw Exception('La imagen es muy pesada. Elige una más pequeña.');
  }
  return encoded;
}

/// Muestra una imagen guardada en base64, o un recuadro con ícono si no hay.
class Base64Image extends StatelessWidget {
  const Base64Image({
    super.key,
    required this.data,
    this.width,
    this.height,
    this.radius = 12,
    this.placeholderIcon = Icons.image_outlined,
    this.fit = BoxFit.cover,
  });

  final String? data;
  final double? width;
  final double? height;
  final double radius;
  final IconData placeholderIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final value = data;
    final bytes = value == null ? null : _decode(value);
    final Widget child = bytes == null
        ? Container(
            color: AppColors.mist,
            alignment: Alignment.center,
            child: Icon(placeholderIcon, color: AppColors.muted),
          )
        : Image.memory(bytes, fit: fit, gaplessPlayback: true);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

/// Proporción (alto / ancho) de cada imagen ya medida.
final Map<String, double> _ratioCache = {};

Future<double> _ratioOf(String data, Uint8List bytes) async {
  final cached = _ratioCache[data];
  if (cached != null) return cached;
  final codec = await instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final ratio = img.width == 0 ? 1.0 : img.height / img.width;
  img.dispose();
  if (_ratioCache.length > 200) _ratioCache.clear();
  _ratioCache[data] = ratio;
  return ratio;
}

/// Imagen de publicación como en Instagram o Facebook: ocupa todo el ancho
/// y su alto sale de la forma de la foto. Solo las fotos MUY altas o MUY
/// anchas se ajustan a 4:5 o 1.91:1 (igual que Instagram), sin franjas.
class AdaptiveImage extends StatelessWidget {
  const AdaptiveImage({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(data);
    if (bytes == null) return const SizedBox.shrink();
    return FutureBuilder<double>(
      future: _ratioOf(data, bytes),
      initialData: _ratioCache[data],
      builder: (context, snap) {
        final ratio = (snap.data ?? 1.0).clamp(1 / 1.91, 1.25);
        return AspectRatio(
          aspectRatio: 1 / ratio,
          child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        );
      },
    );
  }
}

/// Imagen completa dentro de un recuadro de tamaño fijo: se ve entera
/// (sin recortes) y el espacio que sobra se rellena con la misma foto
/// desenfocada, como hacen las apps de fotos.
class FramedImage extends StatelessWidget {
  const FramedImage({super.key, required this.data, this.radius = 16});

  final String data;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(data);
    if (bytes == null) return Container(color: AppColors.mist);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
          ),
          Container(color: const Color(0x22FFFFFF)),
          Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
        ],
      ),
    );
  }
}

/// Recuadro para elegir, cambiar o quitar una imagen en un formulario.
class ImagePickerBox extends StatelessWidget {
  const ImagePickerBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 180,
    this.label = 'Agregar imagen',
    this.maxSize = 900,
    this.quality = 70,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final double height;
  final String label;
  final double maxSize;
  final int quality;

  Future<void> _pick(BuildContext context) async {
    try {
      final picked = await pickImageAsBase64(maxSize: maxSize, quality: quality);
      if (picked != null) onChanged(picked);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = value;
    if (current == null) {
      return InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gray, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  size: 40, color: AppColors.teal),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: AppColors.teal)),
              const Text('JPG o PNG',
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Base64Image(data: current, height: height, width: double.infinity, radius: 14),
        Positioned(
          right: 8,
          top: 8,
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Cambiar imagen',
                onPressed: () => _pick(context),
                icon: const Icon(Icons.edit),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Quitar imagen',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
