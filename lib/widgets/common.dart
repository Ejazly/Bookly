import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import 'site_widgets.dart';

/// Rectángulo con degradado que sustituye a las fotos mientras no
/// tengamos imágenes reales en Firebase Storage.
class GradientBox extends StatelessWidget {
  const GradientBox({
    super.key,
    required this.colors,
    this.width,
    this.height,
    this.radius = 12,
    this.child,
  });

  final List<Color> colors;
  final double? width;
  final double? height;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Tarjeta blanca con esquinas redondeadas y sombra suave.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.borderColor,
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: border != null ? Border.all(color: border, width: 2) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14143F48),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña de estado: "Abierto", "Confirmada", etc.
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.text, {
    super.key,
    this.color = AppColors.green,
    this.background = AppColors.greenSoft,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Botón verde que ocupa todo el ancho. Si [loading] es true muestra
/// un indicador de carga; si [onPressed] es null aparece deshabilitado.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Título pequeño en mayúsculas para separar secciones.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// Estilo común de los campos de texto.
InputDecoration fieldDecoration(String hint, {IconData? icon}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted),
    prefixIcon: icon != null ? Icon(icon) : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(AppColors.gray, 1),
    enabledBorder: border(AppColors.gray, 1),
    focusedBorder: border(AppColors.teal, 2),
    errorBorder: border(AppColors.red, 1),
    focusedErrorBorder: border(AppColors.red, 2),
  );
}

/// Muestra un aviso abajo de la pantalla.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showSoon(BuildContext context) =>
    showMessage(context, 'Esta función estará disponible próximamente.');

/// Diálogo con un ícono, título y mensaje.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required Color color,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icon, color: color, size: 52),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

/// Diálogo de confirmación. Regresa true si la usuaria acepta.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color color = AppColors.teal,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Tarjeta de negocio que se usa en la lista de Inicio.
class BusinessCard extends StatelessWidget {
  const BusinessCard({
    super.key,
    required this.business,
    required this.now,
    required this.onTap,
  });

  final Business business;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final open = b.isOpenAt(now);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          BusinessLogo(business: b),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                if (b.slogan.isNotEmpty)
                  Text(
                    b.slogan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: b.accent, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${b.categoryLabel} · ${b.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (b.rating > 0) ...[
                      const Icon(Icons.star, color: AppColors.amber, size: 16),
                      const SizedBox(width: 3),
                      Text(b.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12)),
                    ] else
                      const Text('Nuevo en Bookly',
                          style: TextStyle(fontSize: 12, color: AppColors.blue)),
                    Text(' · ${b.hoursText}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          open
              ? const StatusBadge('Abierto')
              : const StatusBadge(
                  'Cerrado',
                  color: AppColors.muted,
                  background: AppColors.light,
                ),
        ],
      ),
    );
  }
}

/// Muestra un indicador de carga o un mensaje de error para un StreamBuilder.
/// Regresa null cuando ya hay datos.
Widget? streamStatus(AsyncSnapshot<Object?> snapshot, {String? emptyHint}) {
  if (snapshot.hasError) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'No se pudieron cargar los datos.\n${snapshot.error}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.red),
      ),
    );
  }
  if (!snapshot.hasData) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
  return null;
}

/// Mensaje centrado para listas vacías.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.teal),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}


/// Limita el ancho del contenido en pantallas grandes (computadora), como
/// hacen Instagram y Facebook, para que las fotos no se vean gigantes.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 620});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}
