import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Mapa base de Bookly: teselas estándar de OpenStreetMap (sin llave ni cuenta).
///
/// Es el único lugar donde se define el proveedor de mapas. Si algún día se
/// cambia por otro (por ejemplo uno con plan de pago), solo se edita aquí.
///
/// Política de uso de OpenStreetMap: https://operations.osmfoundation.org/policies/tiles/
/// Sirve para desarrollo y poco tráfico; antes de una publicación con muchos
/// usuarios conviene un proveedor propio (ver ROADMAP.md).
const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Capa de teselas lista para usar dentro de `children` de un `FlutterMap`.
TileLayer booklyTileLayer() => TileLayer(
      urlTemplate: tileUrl,
      maxNativeZoom: 19,
      userAgentPackageName: 'mx.uaq.bookly',
    );

/// Créditos que exige OpenStreetMap; deben verse siempre sobre el mapa.
Widget booklyAttribution() => const RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [TextSourceAttribution('© colaboradores de OpenStreetMap')],
    );
