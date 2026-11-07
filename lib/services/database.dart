import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Todas las lecturas y escrituras a Cloud Firestore pasan por aquí.
///
/// Colecciones:
///   users/{uid}                      perfil y roles de cada cuenta
///   businesses/{uid}                 datos del negocio (id = uid del dueño)
///   businesses/{uid}/items/{itemId}  inventario: servicios y productos
///   posts/{postId}                   publicaciones de los negocios
///   appointments/{id}                citas (solo las escribe el servidor)
///   businesses/{uid}/busy/{id}       horarios ocupados, sin datos personales
///   orders/{id}                      compras de productos
///   paymentStatus/{uid}              si el negocio ya cobra en línea
///   users|businesses/.../movements   pagos, ventas y reembolsos
class Database {
  Database._();

  static final Database instance = Database._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _businesses =>
      _db.collection('businesses');
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _appointments =>
      _db.collection('appointments');
  CollectionReference<Map<String, dynamic>> _items(String businessId) =>
      _businesses.doc(businessId).collection('items');

  // ---------------------------------------------------------------------------
  // Usuarios
  // ---------------------------------------------------------------------------

  Stream<UserProfile?> profileStream(String uid) =>
      _users.doc(uid).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : UserProfile.fromMap(uid, data);
      });

  Future<void> saveProfile(UserProfile p) => _users.doc(p.uid).set({
        ...p.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> updateProfile(String uid, Map<String, dynamic> data) =>
      _users.doc(uid).update(data);

  // ---------------------------------------------------------------------------
  // Negocios
  // ---------------------------------------------------------------------------

  Stream<Business?> businessStream(String id) =>
      _businesses.doc(id).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : Business.fromMap(id, data);
      });

  Future<Business?> getBusiness(String id) async {
    final s = await _businesses.doc(id).get();
    final data = s.data();
    return data == null ? null : Business.fromMap(id, data);
  }

  Stream<List<Business>> businessesStream() =>
      _businesses.snapshots().map((q) {
        final list = q.docs.map((d) => Business.fromMap(d.id, d.data())).toList();
        // Primero los negocios reales, luego los de ejemplo.
        list.sort((a, b) {
          if (a.demo != b.demo) return a.demo ? 1 : -1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return list;
      });

  /// Guarda solo los datos generales (no borra el diseño del sitio).
  Future<void> saveBusinessBasics(Business b) => _businesses.doc(b.id).set({
        ...b.basicMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Guarda el diseño del sitio: portada, logo, color, textos y redes.
  Future<void> saveSite(Business b) => _businesses.doc(b.id).update({
        ...b.siteMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ---------------------------------------------------------------------------
  // Galería de fotos del sitio
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _gallery(String businessId) =>
      _businesses.doc(businessId).collection('gallery');

  Stream<List<GalleryPhoto>> galleryStream(String businessId) =>
      _gallery(businessId).snapshots().map((q) {
        final list = q.docs.map((d) => GalleryPhoto.fromMap(d.id, d.data())).toList();
        final far = DateTime(9999);
        list.sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
        return list;
      });

  Future<void> addGalleryPhoto(String businessId, String imageBase64) =>
      _gallery(businessId).add({
        'imageBase64': imageBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteGalleryPhoto(String businessId, String photoId) =>
      _gallery(businessId).doc(photoId).delete();

  // ---------------------------------------------------------------------------
  // Inventario (servicios y productos)
  // ---------------------------------------------------------------------------

  Stream<List<Item>> itemsStream(String businessId) =>
      _items(businessId).snapshots().map((q) {
        final list = q.docs.map((d) => Item.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Crea el producto si no tiene id; si ya tiene, lo actualiza.
  Future<void> saveItem(String businessId, Item item) async {
    if (item.id.isEmpty) {
      await _items(businessId).add({
        ...item.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _items(businessId).doc(item.id).set(item.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> updateItem(String businessId, String itemId, Map<String, dynamic> data) =>
      _items(businessId).doc(itemId).update(data);

  /// Suma o resta existencias (ej. +1 al recibir mercancía, -1 al vender).
  Future<void> changeStock(String businessId, String itemId, int delta) =>
      updateItem(businessId, itemId, {'stock': FieldValue.increment(delta)});

  Future<void> deleteItem(String businessId, String itemId) =>
      _items(businessId).doc(itemId).delete();

  // ---------------------------------------------------------------------------
  // Publicaciones
  // ---------------------------------------------------------------------------

  List<Post> _postsFrom(QuerySnapshot<Map<String, dynamic>> q) {
    final list = q.docs.map((d) => Post.fromMap(d.id, d.data())).toList();
    // Las recién creadas aún no tienen fecha del servidor: van primero.
    final far = DateTime(9999);
    list.sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
    return list;
  }

  /// Últimas publicaciones de todos los negocios (sección Novedades).
  Stream<List<Post>> feedStream() =>
      _posts.orderBy('createdAt', descending: true).limit(50).snapshots().map(_postsFrom);

  Stream<List<Post>> postsByBusiness(String businessId) =>
      _posts.where('businessId', isEqualTo: businessId).snapshots().map(_postsFrom);

  Future<void> addPost(Post post) => _posts.add({
        ...post.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deletePost(String postId) => _posts.doc(postId).delete();

  // ---------------------------------------------------------------------------
  // Citas
  // ---------------------------------------------------------------------------

  List<Appointment> _appointmentsFrom(QuerySnapshot<Map<String, dynamic>> q) {
    final list = q.docs.map((d) => Appointment.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  Query<Map<String, dynamic>> _dayQuery(String businessId, DateTime day) => _appointments
      .where('businessId', isEqualTo: businessId)
      .where('day', isEqualTo: dayKey(day));

  /// Citas de un negocio en un día (se actualiza solo cuando alguien agenda).
  Stream<List<Appointment>> appointmentsForDay(String businessId, DateTime day) =>
      _dayQuery(businessId, day).snapshots().map(_appointmentsFrom);

  Future<List<Appointment>> fetchAppointmentsForDay(String businessId, DateTime day) async =>
      _appointmentsFrom(await _dayQuery(businessId, day).get());

  /// Citas de un negocio desde hoy en adelante (vista "Próximas" de la agenda).
  Stream<List<Appointment>> upcomingForBusiness(String businessId) => _appointments
      .where('businessId', isEqualTo: businessId)
      .snapshots()
      .map((q) {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        return _appointmentsFrom(q)
            .where((a) => !a.isCancelled && !a.start.isBefore(start))
            .toList();
      });

  /// Citas de un cliente. Se buscan por su Gmail para que también aparezcan
  /// las que el negocio le agregó a mano.
  Stream<List<Appointment>> appointmentsForClient(String email) => _appointments
      .where('clientEmail', isEqualTo: email.toLowerCase())
      .snapshots()
      .map(_appointmentsFrom);

  /// Una sola cita (para ver en vivo cuándo se confirma el pago).
  Stream<Appointment?> appointmentStream(String id) =>
      _appointments.doc(id).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : Appointment.fromMap(s.id, data);
      });

  /// Horarios ocupados de un negocio en un día, SIN datos de los clientes.
  /// Los escribe el servidor en `businesses/{id}/busy` para que cualquier
  /// cliente sepa qué está libre sin poder ver quién reservó.
  Stream<List<Appointment>> busyForDay(String businessId, DateTime day) => _businesses
      .doc(businessId)
      .collection('busy')
      .where('day', isEqualTo: dayKey(day))
      .snapshots()
      .map(_appointmentsFrom);

  // Crear, cancelar y reprogramar citas ya NO se hace aquí: lo hace el
  // servidor (ver services/payments_service.dart), porque involucra dinero.

  // ---------------------------------------------------------------------------
  // Pagos (solo lectura: todo lo escribe el servidor)
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  /// ¿El negocio ya puede cobrar en línea?
  Stream<PayoutStatus> payoutStatusStream(String businessId) => _db
      .collection('paymentStatus')
      .doc(businessId)
      .snapshots()
      .map((s) => PayoutStatus.fromMap(s.data()));

  Stream<ShopOrder?> orderStream(String id) => _orders.doc(id).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : ShopOrder.fromMap(s.id, data);
      });

  List<ShopOrder> _ordersFrom(QuerySnapshot<Map<String, dynamic>> q) {
    final list = q.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList();
    final far = DateTime(9999);
    list.sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
    return list;
  }

  /// Compras que hizo una persona.
  Stream<List<ShopOrder>> ordersForBuyer(String uid) =>
      _orders.where('buyerUid', isEqualTo: uid).snapshots().map(_ordersFrom);

  /// Ventas de un negocio.
  Stream<List<ShopOrder>> ordersForBusiness(String businessId) =>
      _orders.where('businessId', isEqualTo: businessId).snapshots().map(_ordersFrom);

  Stream<List<Movement>> _movements(CollectionReference<Map<String, dynamic>> ref) => ref
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((q) => q.docs.map((d) => Movement.fromMap(d.id, d.data())).toList());

  /// Pagos y reembolsos del cliente.
  Stream<List<Movement>> userMovements(String uid) =>
      _movements(_users.doc(uid).collection('movements'));

  /// Ingresos del negocio (con la comisión de Bookly).
  Stream<List<Movement>> businessMovements(String businessId) =>
      _movements(_businesses.doc(businessId).collection('movements'));

  // ---------------------------------------------------------------------------
  // Datos de ejemplo
  // ---------------------------------------------------------------------------

  /// Guarda los negocios de ejemplo una sola vez.
  Future<void> ensureDemoData() async {
    final first = await _businesses.doc(demoBusinesses.first.id).get();
    if (first.exists) return;
    final batch = _db.batch();
    for (final b in demoBusinesses) {
      batch.set(_businesses.doc(b.id), b.toMap());
      for (final item in demoItems[b.id] ?? const <Item>[]) {
        batch.set(_items(b.id).doc(), {
          ...item.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    for (final p in demoPosts) {
      batch.set(_posts.doc(), {
        ...p.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
