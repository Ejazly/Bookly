import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/database.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/images.dart';
import '../../widgets/site_widgets.dart';
import '../business_screen.dart';
import '../business_setup_screen.dart';
import 'posts_screen.dart';

/// Apartado "Mi sitio": el negocio decora la página que ven sus clientes.
/// Portada, logo, color, eslogan, descripción, redes, galería y publicaciones.
class SiteEditorScreen extends StatefulWidget {
  const SiteEditorScreen({super.key, required this.business});

  final Business business;

  @override
  State<SiteEditorScreen> createState() => _SiteEditorScreenState();
}

class _SiteEditorScreenState extends State<SiteEditorScreen> {
  static const int _maxPhotos = 12;

  late final TextEditingController _slogan =
      TextEditingController(text: widget.business.slogan);
  late final TextEditingController _description =
      TextEditingController(text: widget.business.description);
  late final TextEditingController _whatsapp =
      TextEditingController(text: widget.business.whatsapp);
  late final TextEditingController _instagram =
      TextEditingController(text: widget.business.instagram);
  late final TextEditingController _facebook =
      TextEditingController(text: widget.business.facebook);
  late int _theme = widget.business.themeIndex;
  late String? _logo = widget.business.logoBase64;
  late String? _cover = widget.business.coverBase64;

  late final Stream<List<GalleryPhoto>> _gallery =
      Database.instance.galleryStream(widget.business.id);
  late final Stream<List<Post>> _posts =
      Database.instance.postsByBusiness(widget.business.id);

  bool _dirty = false;
  bool _saving = false;
  bool _addingPhoto = false;

  @override
  void dispose() {
    _slogan.dispose();
    _description.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _facebook.dispose();
    super.dispose();
  }

  /// El negocio con los cambios que aún no se guardan (para la vista previa).
  Business get _draft => widget.business.withSite(
        slogan: _slogan.text.trim(),
        description: _description.text.trim(),
        themeIndex: _theme,
        logoBase64: _logo,
        coverBase64: _cover,
        whatsapp: _whatsapp.text.trim(),
        instagram: _instagram.text.trim().replaceFirst('@', ''),
        facebook: _facebook.text.trim(),
      );

  void _changed() => setState(() => _dirty = true);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Database.instance.saveSite(_draft);
      if (!mounted) return;
      setState(() => _dirty = false);
      showMessage(context, 'Tu sitio se guardó. Así lo verán tus clientes.');
    } catch (e) {
      if (mounted) {
        showMessage(context, 'No se pudo guardar: $e. Si subiste imágenes muy grandes, prueba con otras.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await pickImageAsBase64(maxSize: 400, quality: 75);
      if (picked == null) return;
      setState(() {
        _logo = picked;
        _dirty = true;
      });
    } catch (e) {
      if (mounted) showMessage(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _addPhoto(int current) async {
    if (current >= _maxPhotos) {
      showMessage(context, 'Puedes tener hasta $_maxPhotos fotos. Borra alguna para subir otra.');
      return;
    }
    setState(() => _addingPhoto = true);
    try {
      final picked = await pickImageAsBase64();
      if (picked != null) {
        await Database.instance.addGalleryPhoto(widget.business.id, picked);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  Future<void> _deletePhoto(GalleryPhoto p) async {
    final ok = await confirmDialog(
      context,
      title: '¿Quitar esta foto?',
      message: 'Dejará de aparecer en tu sitio.',
      confirmLabel: 'Quitar',
      color: AppColors.red,
    );
    if (!ok) return;
    try {
      await Database.instance.deleteGalleryPhoto(widget.business.id, p.id);
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo quitar: $e');
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _paletteCircle(int index) {
    final colors = index == 0 ? widget.business.category.colors : sitePalettes[index];
    final selected = _theme == index;
    return GestureDetector(
      onTap: () {
        _theme = index;
        _changed();
      },
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
              border: Border.all(
                color: selected ? AppColors.ink : Colors.white,
                width: selected ? 3 : 2,
              ),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
            ),
            child: selected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
          const SizedBox(height: 4),
          Text(index == 0 ? 'Auto' : '$index', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _linkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mist,
            child: Icon(icon, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi sitio'),
        actions: [
          TextButton.icon(
            onPressed: () => _open(BusinessScreen(business: b, preview: true)),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Ver como cliente'),
          ),
        ],
      ),
      bottomNavigationBar: _dirty
          ? SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                child: PrimaryButton(
                  label: 'Guardar cambios del sitio',
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
        children: [
          if (!b.hasSiteDesign)
            AppCard(
              color: AppColors.greenSoft,
              child: Row(
                children: [
                  const Icon(Icons.celebration_outlined, color: AppColors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡${b.name} ya está en Bookly! Paso 2 de 2: decora tu sitio con '
                      'una portada, tu logo, colores y fotos para que los clientes te conozcan.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SectionLabel('Vista previa'),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IgnorePointer(
              child: BusinessSiteHeader(business: draft, coverHeight: 120),
            ),
          ),
          if (_dirty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Tienes cambios sin guardar.',
                style: TextStyle(color: Color(0xFFB57511), fontSize: 12),
              ),
            ),

          const SectionLabel('Portada'),
          ImagePickerBox(
            value: _cover,
            height: 150,
            label: 'Agregar foto de portada',
            maxSize: 1200,
            quality: 65,
            onChanged: (v) {
              _cover = v;
              _changed();
            },
          ),

          const SectionLabel('Logo'),
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: ClipOval(
                  child: _logo != null
                      ? Base64Image(data: _logo, radius: 0)
                      : Container(
                          color: draft.accent,
                          alignment: Alignment.center,
                          child: const Icon(Icons.storefront, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.upload_outlined),
                label: Text(_logo == null ? 'Subir logo' : 'Cambiar'),
              ),
              if (_logo != null) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {
                    _logo = null;
                    _changed();
                  },
                  child: const Text('Quitar'),
                ),
              ],
            ],
          ),

          const SectionLabel('Color del sitio'),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (var i = 0; i < sitePalettes.length; i++) _paletteCircle(i),
            ],
          ),

          const SectionLabel('Presentación'),
          TextField(
            controller: _slogan,
            maxLength: 60,
            onChanged: (_) => _changed(),
            decoration: fieldDecoration('Eslogan (ej. "Tu estilo, nuestro arte")'),
          ),
          TextField(
            controller: _description,
            maxLines: 5,
            maxLength: 500,
            onChanged: (_) => _changed(),
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDecoration('Acerca de tu negocio: experiencia, especialidades, ambiente...'),
          ),

          const SectionLabel('Contacto y redes sociales'),
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _changed(),
            decoration: fieldDecoration('WhatsApp (10 dígitos)', icon: Icons.chat_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _instagram,
            onChanged: (_) => _changed(),
            decoration: fieldDecoration('Usuario de Instagram (sin @)',
                icon: Icons.camera_alt_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _facebook,
            onChanged: (_) => _changed(),
            decoration: fieldDecoration('Página de Facebook', icon: Icons.facebook),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _dirty ? 'Guardar cambios del sitio' : 'Sitio guardado',
            loading: _saving,
            onPressed: _dirty ? _save : null,
          ),

          StreamBuilder<List<GalleryPhoto>>(
            stream: _gallery,
            builder: (context, snapshot) {
              final photos = snapshot.data ?? const <GalleryPhoto>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel('Galería de fotos (${photos.length}/$_maxPhotos)'),
                  const Text(
                    'Muestra tus trabajos, tu local o tu equipo. Las fotos se publican al momento.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.hasError)
                    Text('No se pudo cargar la galería: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.red))
                  else
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        InkWell(
                          onTap: _addingPhoto ? null : () => _addPhoto(photos.length),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gray, width: 1.5),
                            ),
                            child: Center(
                              child: _addingPhoto
                                  ? const CircularProgressIndicator()
                                  : const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_a_photo_outlined, color: AppColors.teal),
                                        SizedBox(height: 4),
                                        Text('Agregar', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        for (final p in photos)
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              Base64Image(data: p.imageBase64, radius: 10),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _deletePhoto(p),
                                  child: const CircleAvatar(
                                    radius: 13,
                                    backgroundColor: Color(0xCC000000),
                                    child: Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              );
            },
          ),

          const SectionLabel('Más secciones de tu sitio'),
          StreamBuilder<List<Post>>(
            stream: _posts,
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return _linkCard(
                icon: Icons.campaign_outlined,
                title: 'Publicaciones ($count)',
                subtitle: 'Promociones y novedades que aparecen en tu sitio y en Novedades.',
                onTap: () => _open(PostsScreen(business: b)),
              );
            },
          ),
          const SizedBox(height: 8),
          _linkCard(
            icon: Icons.edit_note,
            title: 'Datos generales',
            subtitle: 'Nombre, categoría, dirección, teléfono, horario y personal.',
            onTap: () => _open(BusinessSetupScreen(existing: b)),
          ),
        ],
      ),
    );
  }
}
