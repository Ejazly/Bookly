import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database.dart';

/// Estado de la sesión: quién inició sesión, su perfil, su negocio (si tiene)
/// y la interfaz que está usando (cliente o negocio).
///
/// Es un [ChangeNotifier]: cuando algo cambia llama a `notifyListeners()` y
/// las pantallas que lo usan se vuelven a dibujar solas.
class AppSession extends ChangeNotifier {
  AppSession() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserProfile?>? _profileSub;
  StreamSubscription<Business?>? _businessSub;

  User? user;
  UserProfile? profile;
  Business? myBusiness;

  bool authLoaded = false;
  bool profileLoaded = false;
  bool businessLoaded = false;

  /// Último error al leer Firestore (por ejemplo, reglas mal configuradas).
  String? loadError;

  // Pestaña seleccionada en cada interfaz.
  int _clientTab = 0;
  int _businessTab = 0;

  int get clientTab => _clientTab;
  set clientTab(int value) {
    _clientTab = value;
    notifyListeners();
  }

  int get businessTab => _businessTab;
  set businessTab(int value) {
    _businessTab = value;
    notifyListeners();
  }

  /// Gmail de la cuenta, en minúsculas.
  String get email => (user?.email ?? profile?.email ?? '').toLowerCase();

  String get displayName {
    final fromProfile = profile?.name ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    final fromGoogle = user?.displayName ?? '';
    if (fromGoogle.isNotEmpty) return fromGoogle;
    return email.split('@').first;
  }

  String get firstName => displayName.split(' ').first;

  AppMode get mode => profile?.mode ?? AppMode.client;

  void _onAuthChanged(User? u) {
    user = u;
    authLoaded = true;
    _profileSub?.cancel();
    _businessSub?.cancel();
    profile = null;
    myBusiness = null;
    profileLoaded = false;
    businessLoaded = false;
    loadError = null;
    _clientTab = 0;
    _businessTab = 0;

    if (u != null) {
      _profileSub = Database.instance.profileStream(u.uid).listen(
        (p) {
          profile = p;
          profileLoaded = true;
          notifyListeners();
        },
        onError: (Object e) {
          loadError = e.toString();
          profileLoaded = true;
          notifyListeners();
        },
      );
      _businessSub = Database.instance.businessStream(u.uid).listen(
        (b) {
          myBusiness = b;
          businessLoaded = true;
          notifyListeners();
        },
        onError: (Object e) {
          loadError = e.toString();
          businessLoaded = true;
          notifyListeners();
        },
      );
      _seedDemoData();
    }
    notifyListeners();
  }

  Future<void> _seedDemoData() async {
    try {
      await Database.instance.ensureDemoData();
    } catch (_) {
      // Si las reglas no lo permiten, la app sigue funcionando sin ejemplos.
    }
  }

  /// Después de verificar el correo: vuelve a leer la cuenta y redibuja.
  Future<bool> refreshVerification() async {
    final ok = await AuthService.reloadAndCheckVerified();
    if (ok) {
      // Se vuelven a abrir las lecturas con el permiso ya verificado.
      _onAuthChanged(FirebaseAuth.instance.currentUser);
    }
    return ok;
  }

  /// Se llama al terminar el registro (pantalla "¿Cómo usarás Bookly?").
  Future<void> createProfile({
    required String name,
    required bool asClient,
    required bool asBusiness,
  }) async {
    final u = user;
    if (u == null) return;
    await Database.instance.saveProfile(UserProfile(
      uid: u.uid,
      name: name,
      email: (u.email ?? '').toLowerCase(),
      isClient: asClient,
      isBusiness: asBusiness,
      // Si eligió negocio, empieza por configurarlo.
      mode: asBusiness ? AppMode.business : AppMode.client,
    ));
  }

  /// Cambia de interfaz. Si la cuenta todavía no tenía ese perfil, lo activa.
  Future<void> switchMode(AppMode newMode) async {
    final p = profile;
    if (p == null) return;
    await Database.instance.updateProfile(p.uid, {
      'mode': newMode.name,
      if (newMode == AppMode.business) 'isBusiness': true,
      if (newMode == AppMode.client) 'isClient': true,
    });
  }

  Future<void> signOut() => AuthService.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _businessSub?.cancel();
    super.dispose();
  }
}

/// Hace que [AppSession] esté disponible en todas las pantallas.
///
/// - `AppScope.of(context)` dentro de `build`: la pantalla se redibuja sola.
/// - `AppScope.read(context)` dentro de botones o funciones.
class AppScope extends InheritedNotifier<AppSession> {
  const AppScope({super.key, required AppSession session, required super.child})
      : super(notifier: session);

  static AppSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
