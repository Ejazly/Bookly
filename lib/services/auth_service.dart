import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Inicio de sesión con la cuenta de Google (Gmail) usando Firebase Auth.
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
          return 'El inicio de sesión con Google no está activado en Firebase (Authentication → Sign-in method → Google).';
        case 'unauthorized-domain':
          return 'Este dominio no está autorizado en Firebase (Authentication → Settings → Authorized domains).';
        case 'network-request-failed':
          return 'No hay conexión a internet.';
      }
      return 'No se pudo iniciar sesión (${error.code}).';
    }
    return 'No se pudo iniciar sesión: $error';
  }
}
