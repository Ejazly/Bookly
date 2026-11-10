import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Inicio de sesión con Firebase Auth. Hay dos formas:
///  - Con Google (un toque si ya tienes tu Gmail abierto).
///  - Con correo y contraseña creados en la app. En ese caso se manda un
///    correo para verificar que la dirección es real antes de dejar entrar.
/// Bookly nunca guarda contraseñas: las guarda Firebase, cifradas.
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  /// Abre la ventana de Google para elegir la cuenta.
  /// - En Chrome (web) se usa una ventana emergente.
  /// - En Android se abre el navegador del celular.
  static Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  /// Crea una cuenta con correo y contraseña y manda el correo de verificación.
  static Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = cred.user;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await _auth.setLanguageCode('es');
    await user.sendEmailVerification();
  }

  static Future<void> signInWithEmail({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);

  /// Manda un correo para crear una contraseña nueva.
  static Future<void> sendPasswordReset(String email) async {
    await _auth.setLanguageCode('es');
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  static Future<void> resendVerification() async {
    await _auth.setLanguageCode('es');
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Vuelve a leer la cuenta (para saber si ya verificó su correo) y renueva
  /// el permiso de sesión para que el servidor también lo sepa.
  static Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh != null && fresh.emailVerified) {
      await fresh.getIdToken(true);
      return true;
    }
    return false;
  }

  /// ¿La cuenta entró con contraseña y todavía no verifica su correo?
  static bool needsVerification(User user) =>
      !user.emailVerified && user.providerData.any((p) => p.providerId == 'password');

  static Future<void> signOut() => _auth.signOut();

  /// Convierte los errores de Firebase en mensajes entendibles.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'web-context-canceled':
          return 'Cerraste la ventana de Google antes de terminar.';
        case 'popup-blocked':
          return 'El navegador bloqueó la ventana de Google. Permite las ventanas emergentes e inténtalo de nuevo.';
        case 'operation-not-allowed':
          return 'Este método de inicio de sesión no está activado en Firebase (Authentication → Sign-in method).';
        case 'unauthorized-domain':
          return 'Este dominio no está autorizado en Firebase (Authentication → Settings → Authorized domains).';
        case 'network-request-failed':
          return 'No hay conexión a internet.';
        case 'email-already-in-use':
          return 'Ya existe una cuenta con ese correo. Inicia sesión (o entra con Google si así la creaste).';
        case 'invalid-email':
          return 'Ese correo no es válido.';
        case 'weak-password':
        case 'password-does-not-meet-requirements':
          return 'La contraseña es muy débil. Usa al menos 8 caracteres con letras y números.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-login-credentials':
          return 'Correo o contraseña incorrectos.';
        case 'user-disabled':
          return 'Esta cuenta está desactivada.';
        case 'too-many-requests':
          return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
        case 'account-exists-with-different-credential':
          return 'Ese correo ya tiene cuenta con otro método. Entra con correo y contraseña.';
        case 'missing-password':
          return 'Escribe tu contraseña.';
      }
      return 'No se pudo iniciar sesión (${error.code}).';
    }
    return 'No se pudo iniciar sesión: $error';
  }
}
