import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';

/// Crear una publicación nueva: texto y una imagen (opcional).
class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, required this.business});

  final Business business;

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  String? _image;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final b = widget.business;
    setState(() => _saving = true);
    try {
      await Database.instance.addPost(Post(
        id: '',
        businessId: b.id,
        businessName: b.name,
        category: b.category,
        text: _text.text.trim(),
        imageBase64: _image,
      ));
      if (!mounted) return;
      showMessage(context, '¡Publicado!');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo publicar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            ImagePickerBox(
              value: _image,
              height: 220,
              label: 'Agregar foto (opcional)',
              onChanged: (v) => setState(() => _image = v),
            ),
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
              'Idea: anuncia una promoción, muestra un trabajo reciente o avisa de un horario especial.',
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
