import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Porcentaje del costo que se paga por adelantado al reservar desde la app.
const double depositRate = 0.25;

/// Calcula el anticipo (25 %) redondeado a centavos.
double depositFor(double price) =>
    (price * depositRate * 100).roundToDouble() / 100;

// -----------------------------------------------------------------------------
// Funciones pequeñas para leer datos de Firestore sin que la app truene si
// un campo falta o viene con otro tipo.
// -----------------------------------------------------------------------------

DateTime? readDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

double _double(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

String _string(Object? v) => v is String ? v : '';

String? _nullableString(Object? v) => v is String && v.isNotEmpty ? v : null;

bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

List<StaffMember> _staffList(Object? v, int open, int close) => v is List
    ? v
        .whereType<Map>()
        .map((m) => StaffMember.fromMap(Map<String, dynamic>.from(m), open: open, close: close))
        .where((m) => m.name.isNotEmpty)
        .toList()
    : <StaffMember>[];

List<String> _stringList(Object? v) =>
    v is List ? v.whereType<String>().toList() : <String>[];

// -----------------------------------------------------------------------------
// Usuario
// -----------------------------------------------------------------------------

/// Interfaz que la persona está usando en este momento.
enum AppMode { client, business }

AppMode _parseMode(Object? v) =>
    v == AppMode.business.name ? AppMode.business : AppMode.client;

/// Perfil guardado en `users/{uid}`.
/// Una misma cuenta puede tener las dos interfaces (cliente y negocio).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.isClient,
    required this.isBusiness,
    required this.mode,
  });

  final String uid;
  final String name;
  final String email; // correo de Gmail vinculado
  final bool isClient;
  final bool isBusiness;
  final AppMode mode;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) {
    return UserProfile(
      uid: uid,
      name: _string(m['name']),
      email: _string(m['email']),
      isClient: _bool(m['isClient'], true),
      isBusiness: _bool(m['isBusiness']),
      mode: _parseMode(m['mode']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'isClient': isClient,
        'isBusiness': isBusiness,
        'mode': mode.name,
      };
}

// -----------------------------------------------------------------------------
// Negocio
// -----------------------------------------------------------------------------

enum BusinessCategory { barberias, esteticas, spas, unas, otro }

extension BusinessCategoryInfo on BusinessCategory {
  String get label => switch (this) {
        BusinessCategory.barberias => 'Barberías',
        BusinessCategory.esteticas => 'Estéticas',
        BusinessCategory.spas => 'Spas',
        BusinessCategory.unas => 'Uñas',
        BusinessCategory.otro => 'Otros',
      };

  IconData get icon => switch (this) {
        BusinessCategory.barberias => Icons.content_cut,
        BusinessCategory.esteticas => Icons.face_retouching_natural,
        BusinessCategory.spas => Icons.spa,
        BusinessCategory.unas => Icons.brush,
        BusinessCategory.otro => Icons.storefront,
      };

  /// Colores del degradado que se usa como portada.
  List<Color> get colors => switch (this) {
        BusinessCategory.barberias => const [Color(0xFF1E5E6B), Color(0xFF143F48)],
        BusinessCategory.esteticas => const [Color(0xFF28588B), Color(0xFF1E5E6B)],
        BusinessCategory.spas => const [Color(0xFF3E8C92), Color(0xFF1E5E6B)],
        BusinessCategory.unas => const [Color(0xFF4F7FB0), Color(0xFF28588B)],
        BusinessCategory.otro => const [Color(0xFF2F7380), Color(0xFF28588B)],
      };
}

BusinessCategory parseCategory(Object? v) => BusinessCategory.values.firstWhere(
      (c) => c.name == v,
      orElse: () => BusinessCategory.otro,
    );

/// Colores que el negocio puede elegir para decorar su sitio.
/// El índice 0 significa "según la categoría".
const List<List<Color>> sitePalettes = [
  [], // 0 = colores de la categoría
  [Color(0xFF1E5E6B), Color(0xFF28588B)], // turquesa Bookly
  [Color(0xFF28588B), Color(0xFF1B3B66)], // azul
  [Color(0xFF2E9673), Color(0xFF1E5E6B)], // verde
  [Color(0xFFB37FA8), Color(0xFF6D3B63)], // lila
  [Color(0xFFE38B6F), Color(0xFFB0473A)], // coral
  [Color(0xFF3A3A3A), Color(0xFF111111)], // negro
  [Color(0xFFD9A441), Color(0xFF9C6B12)], // dorado
];

/// Persona que atiende en el negocio, con su propio horario.
/// Ej. Evelyn trabaja de 10:00 a 16:00 y descansa los lunes.
class StaffMember {
  const StaffMember({
    required this.name,
    required this.startHour,
    required this.endHour,
    this.daysOff = const <int>{},
  });

  final String name;
  final int startHour; // ej. 10 = 10:00
  final int endHour; // ej. 16 = 16:00
  final Set<int> daysOff; // DateTime.monday ... DateTime.sunday

  bool worksOn(DateTime day) => !daysOff.contains(day.weekday);

  String get hoursText => '$startHour:00 – $endHour:00';

  factory StaffMember.fromMap(Map<String, dynamic> m, {int open = 9, int close = 19}) {
    final off = m['daysOff'];
    return StaffMember(
      name: _string(m['name']),
      startHour: _int(m['startHour'], open),
      endHour: _int(m['endHour'], close),
      daysOff: off is List ? off.whereType<num>().map((n) => n.toInt()).toSet() : <int>{},
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'startHour': startHour,
        'endHour': endHour,
        'daysOff': daysOff.toList()..sort(),
      };
}

/// Negocio guardado en `businesses/{id}`.
/// El id del negocio es el mismo uid de la cuenta dueña (un negocio por cuenta).
///
/// Tiene dos grupos de datos:
///   - datos generales (nombre, dirección, horario...) → [basicMap]
///   - diseño del sitio (portada, logo, color, textos, redes) → [siteMap]
class Business {
  const Business({
    required this.id,
    required this.ownerUid,
    required this.ownerEmail,
    required this.name,
    required this.category,
    required this.address,
    required this.phone,
    required this.openHour,
    required this.closeHour,
    required this.closedWeekdays,
    required this.professionals,
    this.staffMembers = const [],
    this.customCategory = '',
    this.rating = 0,
    this.demo = false,
    this.slogan = '',
    this.description = '',
    this.themeIndex = 0,
    this.logoBase64,
    this.coverBase64,
    this.whatsapp = '',
    this.instagram = '',
    this.facebook = '',
    this.latitude,
    this.longitude,
  });

  final String id;
  final String ownerUid;
  final String ownerEmail; // a este Gmail llegan los avisos de nuevas citas
  final String name;
  final BusinessCategory category;
  final String address;
  final String phone;
  final int openHour; // ej. 10 = 10:00
  final int closeHour; // ej. 20 = 20:00
  final Set<int> closedWeekdays; // DateTime.monday ... DateTime.sunday
  final List<String> professionals; // solo nombres (versiones anteriores)
  final List<StaffMember> staffMembers; // personal con su horario
  final String customCategory; // tipo de negocio escrito a mano si eligió "Otros"
  final double rating;
  final bool demo; // negocios de ejemplo

  // Diseño del sitio
  final String slogan; // frase corta debajo del nombre
  final String description; // "Acerca de nosotros"
  final int themeIndex; // posición en [sitePalettes]
  final String? logoBase64;
  final String? coverBase64;
  final String whatsapp;
  final String instagram;
  final String facebook;

  /// Ubicación en el mapa (la marca el negocio). null = todavía no la marca.
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  /// Colores del sitio: los que eligió el negocio o los de su categoría.
  List<Color> get colors {
    if (themeIndex > 0 && themeIndex < sitePalettes.length) {
      return sitePalettes[themeIndex];
    }
    return category.colors;
  }

  Color get accent => colors.first;

  /// true cuando el negocio ya decoró algo de su sitio.
  bool get hasSiteDesign =>
      description.isNotEmpty || slogan.isNotEmpty || coverBase64 != null || logoBase64 != null;

  /// Tipo de negocio para mostrar: el escrito a mano o el de la categoría.
  String get categoryLabel =>
      category == BusinessCategory.otro && customCategory.trim().isNotEmpty
          ? customCategory.trim()
          : category.label;

  /// Personal con su horario. Si un negocio viejo solo guardó nombres,
  /// cada persona trabaja el horario completo del negocio.
  List<StaffMember> get team {
    if (staffMembers.isNotEmpty) return staffMembers;
    final names = professionals.isEmpty ? const ['Personal'] : professionals;
    return [
      for (final n in names)
        StaffMember(name: n, startHour: openHour, endHour: closeHour),
    ];
  }

  /// Nombres del personal.
  List<String> get staff => [for (final m in team) m.name];

  /// Busca a una persona del personal por nombre.
  StaffMember? memberNamed(String name) {
    for (final m in team) {
      if (m.name == name) return m;
    }
    return null;
  }

  bool isOpenOn(DateTime day) => !closedWeekdays.contains(day.weekday);

  bool isOpenAt(DateTime moment) =>
      isOpenOn(moment) && moment.hour >= openHour && moment.hour < closeHour;

  String get hoursText => '$openHour:00 – $closeHour:00';

  factory Business.fromMap(String id, Map<String, dynamic> m) {
    final closed = m['closedWeekdays'];
    return Business(
      id: id,
      ownerUid: _string(m['ownerUid']),
      ownerEmail: _string(m['ownerEmail']),
      name: _string(m['name']),
      category: parseCategory(m['category']),
      address: _string(m['address']),
      phone: _string(m['phone']),
      openHour: _int(m['openHour'], 9),
      closeHour: _int(m['closeHour'], 19),
      closedWeekdays:
          closed is List ? closed.whereType<num>().map((n) => n.toInt()).toSet() : <int>{},
      professionals: _stringList(m['professionals']),
      staffMembers: _staffList(m['staff'], _int(m['openHour'], 9), _int(m['closeHour'], 19)),
      customCategory: _string(m['customCategory']),
      rating: _double(m['rating']),
      demo: _bool(m['demo']),
      slogan: _string(m['slogan']),
      description: _string(m['description']),
      themeIndex: _int(m['themeIndex']),
      logoBase64: _nullableString(m['logoBase64']),
      coverBase64: _nullableString(m['coverBase64']),
      whatsapp: _string(m['whatsapp']),
      instagram: _string(m['instagram']),
      facebook: _string(m['facebook']),
      latitude: _coordinate(m['lat'], 90),
      longitude: _coordinate(m['lng'], 180),
    );
  }

  static double? _coordinate(Object? v, double limit) {
    if (v is! num) return null;
    final d = v.toDouble();
    return d.isFinite && d.abs() <= limit ? d : null;
  }

  /// Datos generales (pantalla "Datos del negocio").
  Map<String, dynamic> basicMap() => {
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail,
        'name': name,
        'category': category.name,
        'address': address,
        'phone': phone,
        'openHour': openHour,
        'closeHour': closeHour,
        'closedWeekdays': closedWeekdays.toList()..sort(),
        'professionals': staff,
        'staff': [for (final m in staffMembers) m.toMap()],
        'customCategory': customCategory,
        'rating': rating,
        'demo': demo,
        'lat': latitude,
        'lng': longitude,
      };

  /// Diseño del sitio (apartado "Mi sitio").
  Map<String, dynamic> siteMap() => {
        'slogan': slogan,
        'description': description,
        'themeIndex': themeIndex,
        'logoBase64': logoBase64,
        'coverBase64': coverBase64,
        'whatsapp': whatsapp,
        'instagram': instagram,
        'facebook': facebook,
      };

  Map<String, dynamic> toMap() => {...basicMap(), ...siteMap()};

  /// Copia del negocio con otro diseño de sitio (para la vista previa).
  Business withSite({
    required String slogan,
    required String description,
    required int themeIndex,
    required String? logoBase64,
    required String? coverBase64,
    required String whatsapp,
    required String instagram,
    required String facebook,
  }) {
    return Business(
      id: id,
      ownerUid: ownerUid,
      ownerEmail: ownerEmail,
      name: name,
      category: category,
      address: address,
      phone: phone,
      openHour: openHour,
      closeHour: closeHour,
      closedWeekdays: closedWeekdays,
      professionals: professionals,
      staffMembers: staffMembers,
      customCategory: customCategory,
      rating: rating,
      demo: demo,
      slogan: slogan,
      description: description,
      themeIndex: themeIndex,
      logoBase64: logoBase64,
      coverBase64: coverBase64,
      whatsapp: whatsapp,
      instagram: instagram,
      facebook: facebook,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

/// Foto de la galería del sitio: `businesses/{id}/gallery/{photoId}`.
class GalleryPhoto {
  const GalleryPhoto({required this.id, required this.imageBase64, this.createdAt});

  final String id;
  final String imageBase64;
  final DateTime? createdAt;

  factory GalleryPhoto.fromMap(String id, Map<String, dynamic> m) => GalleryPhoto(
        id: id,
        imageBase64: _string(m['imageBase64']),
        createdAt: readDate(m['createdAt']),
      );
}

// -----------------------------------------------------------------------------
// Productos y servicios (inventario)
// -----------------------------------------------------------------------------

/// Un servicio se puede agendar (tiene duración).
/// Un producto se vende en el negocio (tiene existencias).
enum ItemKind { servicio, producto }

ItemKind _parseKind(Object? v) =>
    v == ItemKind.producto.name ? ItemKind.producto : ItemKind.servicio;

/// Elemento del inventario: `businesses/{id}/items/{itemId}`.
class Item {
  const Item({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    this.description = '',
    this.minutes = 60,
    this.stock = 0,
    this.imageBase64,
    this.active = true,
    this.section = '',
  });

  final String id; // vacío cuando todavía no se guarda
  final ItemKind kind;
  final String name;
  final String description;
  final double price;
  final int minutes; // solo servicios
  final int stock; // solo productos
  final String? imageBase64; // imagen comprimida guardada como texto
  final bool active; // si se muestra a los clientes

  /// Clasificación que elige el negocio (ej. "Cortes", "Barba"). Vacío = sin clasificar.
  final String section;

  bool get isService => kind == ItemKind.servicio;
  double get deposit => depositFor(price);

  factory Item.fromMap(String id, Map<String, dynamic> m) {
    return Item(
      id: id,
      kind: _parseKind(m['kind']),
      name: _string(m['name']),
      description: _string(m['description']),
      price: _double(m['price']),
      minutes: _int(m['minutes'], 60),
      stock: _int(m['stock']),
      imageBase64: _nullableString(m['imageBase64']),
      active: _bool(m['active'], true),
      section: _string(m['section']).trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'section': section,
        'kind': kind.name,
        'name': name,
        'description': description,
        'price': price,
        'minutes': minutes,
        'stock': stock,
        'imageBase64': imageBase64,
        'active': active,
      };
}

// -----------------------------------------------------------------------------
// Publicaciones
// -----------------------------------------------------------------------------

/// Publicación de un negocio: `posts/{id}`.
class Post {
  const Post({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.category,
    required this.text,
    this.imageBase64,
    this.videoUrl,
    this.videoPath,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final BusinessCategory category;
  final String text;
  final String? imageBase64;

  /// Video guardado en Firebase Storage (`posts/{uid}/...`).
  final String? videoUrl;
  final String? videoPath;
  final DateTime? createdAt;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  factory Post.fromMap(String id, Map<String, dynamic> m) {
    return Post(
      id: id,
      businessId: _string(m['businessId']),
      businessName: _string(m['businessName']),
      category: parseCategory(m['category']),
      text: _string(m['text']),
      imageBase64: _nullableString(m['imageBase64']),
      videoUrl: _nullableString(m['videoUrl']),
      videoPath: _nullableString(m['videoPath']),
      createdAt: readDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'businessId': businessId,
        'businessName': businessName,
        'category': category.name,
        'text': text,
        'imageBase64': imageBase64,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (videoPath != null) 'videoPath': videoPath,
      };
}

// -----------------------------------------------------------------------------
// Citas
// -----------------------------------------------------------------------------

/// Estados de una cita. [wire] es el texto que guarda el servidor.
enum AppointmentStatus {
  confirmada('confirmada'),
  cancelada('cancelada'),
  pendientePago('pendiente_pago'),
  expirada('expirada'),
  reembolsada('reembolsada');

  const AppointmentStatus(this.wire);

  final String wire;

  static AppointmentStatus parse(Object? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return AppointmentStatus.confirmada;
  }

  String get label => switch (this) {
        AppointmentStatus.confirmada => 'Confirmada',
        AppointmentStatus.cancelada => 'Cancelada',
        AppointmentStatus.pendientePago => 'Esperando pago',
        AppointmentStatus.expirada => 'Pago no completado',
        AppointmentStatus.reembolsada => 'Reembolsada',
      };
}

/// Cita agendada: `appointments/{id}`.
class Appointment {
  const Appointment({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerEmail,
    required this.itemId,
    required this.serviceName,
    required this.minutes,
    required this.price,
    required this.depositPaid,
    required this.professional,
    required this.start,
    required this.clientName,
    required this.clientEmail,
    this.clientUid,
    this.clientPhone = '',
    this.note = '',
    this.status = AppointmentStatus.confirmada,
    this.createdByBusiness = false,
    this.holdExpiresAt,
    this.refundedCents = 0,
    this.cancelledBy = '',
  });

  final String id;
  final String businessId;
  final String businessName;
  final String ownerEmail;
  final String itemId;
  final String serviceName;
  final int minutes;
  final double price;
  final double depositPaid;
  final String professional;
  final DateTime start;
  final String? clientUid; // null si el negocio agregó al cliente a mano
  final String clientName;
  final String clientEmail; // con este correo el cliente ve la cita en su app
  final String clientPhone;
  final String note;
  final AppointmentStatus status;
  final bool createdByBusiness;

  /// Hasta cuándo se aparta el horario mientras el cliente paga.
  final DateTime? holdExpiresAt;

  /// Centavos devueltos al cancelar (lo escribe el servidor).
  final int refundedCents;

  /// 'cliente' o 'negocio'.
  final String cancelledBy;

  DateTime get end => start.add(Duration(minutes: minutes));
  double get remaining => price - depositPaid;

  /// Ya no está activa: cancelada, reembolsada o el pago no se completó.
  bool get isCancelled =>
      status == AppointmentStatus.cancelada ||
      status == AppointmentStatus.expirada ||
      status == AppointmentStatus.reembolsada;

  bool get isPending => status == AppointmentStatus.pendientePago;

  /// ¿Ocupa el horario? Confirmada, o apartada mientras el cliente paga.
  bool blocksSlot(DateTime now) {
    if (status == AppointmentStatus.confirmada) return true;
    if (status == AppointmentStatus.pendientePago) {
      final until = holdExpiresAt;
      return until != null && until.isAfter(now);
    }
    return false;
  }

  factory Appointment.fromMap(String id, Map<String, dynamic> m) {
    return Appointment(
      id: id,
      businessId: _string(m['businessId']),
      businessName: _string(m['businessName']),
      ownerEmail: _string(m['ownerEmail']),
      itemId: _string(m['itemId']),
      serviceName: _string(m['serviceName']),
      minutes: _int(m['minutes'], 60),
      price: _double(m['price']),
      depositPaid: _double(m['depositPaid']),
      professional: _string(m['professional']),
      start: readDate(m['start']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      clientUid: _nullableString(m['clientUid']),
      clientName: _string(m['clientName']),
      clientEmail: _string(m['clientEmail']),
      clientPhone: _string(m['clientPhone']),
      note: _string(m['note']),
      status: AppointmentStatus.parse(m['status']),
      createdByBusiness: _bool(m['createdByBusiness']),
      holdExpiresAt: readDate(m['holdExpiresAt']),
      refundedCents: _int(m['refundedCents'], 0),
      cancelledBy: _string(m['cancelledBy']),
    );
  }

  /// [day] se guarda como texto ("2026-11-05") para buscar las citas de un día.
  Map<String, dynamic> toMap() => {
        'businessId': businessId,
        'businessName': businessName,
        'ownerEmail': ownerEmail,
        'itemId': itemId,
        'serviceName': serviceName,
        'minutes': minutes,
        'price': price,
        'depositPaid': depositPaid,
        'professional': professional,
        'start': Timestamp.fromDate(start),
        'day': dayKey(start),
        'clientUid': clientUid,
        'clientName': clientName,
        'clientEmail': clientEmail.toLowerCase(),
        'clientPhone': clientPhone,
        'note': note,
        'status': status.wire,
        'createdByBusiness': createdByBusiness,
      };

  Appointment copyWith({
    String? id,
    DateTime? start,
    String? professional,
    AppointmentStatus? status,
  }) {
    return Appointment(
      id: id ?? this.id,
      businessId: businessId,
      businessName: businessName,
      ownerEmail: ownerEmail,
      itemId: itemId,
      serviceName: serviceName,
      minutes: minutes,
      price: price,
      depositPaid: depositPaid,
      professional: professional ?? this.professional,
      start: start ?? this.start,
      clientUid: clientUid,
      clientName: clientName,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      note: note,
      status: status ?? this.status,
      createdByBusiness: createdByBusiness,
      holdExpiresAt: holdExpiresAt,
      refundedCents: refundedCents,
      cancelledBy: cancelledBy,
    );
  }
}

/// Clave de día: 2026-11-05.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// -----------------------------------------------------------------------------
// Pagos (todo esto lo escribe SOLO el servidor; la app solo lo lee)
// -----------------------------------------------------------------------------

/// Pesos a partir de centavos: 5750 → 57.50.
double fromCents(Object? cents) => (cents is num ? cents : 0) / 100;

/// Estado público de cobros de un negocio: `paymentStatus/{businessId}`.
class PayoutStatus {
  const PayoutStatus({
    this.connected = false,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.detailsSubmitted = false,
  });

  final bool connected;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;

  factory PayoutStatus.fromMap(Map<String, dynamic>? m) => PayoutStatus(
        connected: _bool(m?['connected']),
        chargesEnabled: _bool(m?['chargesEnabled']),
        payoutsEnabled: _bool(m?['payoutsEnabled']),
        detailsSubmitted: _bool(m?['detailsSubmitted']),
      );
}

/// Tarjeta guardada en Stripe (solo marca, últimos 4 dígitos y vencimiento).
class SavedCard {
  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;

  String get brandLabel => switch (brand) {
        'visa' => 'Visa',
        'mastercard' => 'Mastercard',
        'amex' => 'American Express',
        _ => brand.isEmpty ? 'Tarjeta' : brand[0].toUpperCase() + brand.substring(1),
      };

  String get expiryText =>
      '${expMonth.toString().padLeft(2, '0')}/${(expYear % 100).toString().padLeft(2, '0')}';

  factory SavedCard.fromMap(Map<String, dynamic> m) => SavedCard(
        id: _string(m['id']),
        brand: _string(m['brand']),
        last4: _string(m['last4']),
        expMonth: _int(m['expMonth']),
        expYear: _int(m['expYear']),
      );
}

/// Movimiento de dinero: `users/{uid}/movements` o `businesses/{id}/movements`.
///
/// Para el cliente se usa [amountCents]; para el negocio [grossCents]
/// (lo que pagó el cliente), [feeCents] (comisión de Bookly) y [netCents]
/// (lo que le llega al negocio).
class Movement {
  const Movement({
    required this.id,
    required this.type,
    required this.concept,
    this.businessName = '',
    this.amountCents = 0,
    this.grossCents = 0,
    this.feeCents = 0,
    this.netCents = 0,
    this.createdAt,
  });

  final String id;
  final String type; // anticipo, compra, venta, reembolso, anticipo_en_local
  final String concept;
  final String businessName;
  final int amountCents;
  final int grossCents;
  final int feeCents;
  final int netCents;
  final DateTime? createdAt;

  bool get isRefund => type == 'reembolso';

  factory Movement.fromMap(String id, Map<String, dynamic> m) => Movement(
        id: id,
        type: _string(m['type']),
        concept: _string(m['concept']),
        businessName: _string(m['businessName']),
        amountCents: _int(m['amountCents']),
        grossCents: _int(m['grossCents']),
        feeCents: _int(m['feeCents']),
        netCents: _int(m['netCents']),
        createdAt: readDate(m['createdAt']),
      );
}

/// Compra de un producto: `orders/{id}`.
class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerEmail,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.totalCents,
    required this.buyerName,
    required this.buyerEmail,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String ownerEmail;
  final String itemName;
  final double unitPrice;
  final int quantity;
  final int totalCents;
  final String buyerName;
  final String buyerEmail;
  final String status; // pendiente_pago, pagada, expirada, reembolsada
  final DateTime? createdAt;

  bool get isPaid => status == 'pagada';

  String get statusLabel => switch (status) {
        'pagada' => 'Pagada',
        'pendiente_pago' => 'Esperando pago',
        'reembolsada' => 'Reembolsada',
        _ => 'Pago no completado',
      };

  factory ShopOrder.fromMap(String id, Map<String, dynamic> m) => ShopOrder(
        id: id,
        businessId: _string(m['businessId']),
        businessName: _string(m['businessName']),
        ownerEmail: _string(m['ownerEmail']),
        itemName: _string(m['itemName']),
        unitPrice: _double(m['unitPrice']),
        quantity: _int(m['quantity'], 1),
        totalCents: _int(m['totalCents']),
        buyerName: _string(m['buyerName']),
        buyerEmail: _string(m['buyerEmail']),
        status: _string(m['status']),
        createdAt: readDate(m['createdAt']),
      );
}
