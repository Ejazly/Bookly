import 'package:cloud_functions/cloud_functions.dart';

/// Error de borrado de cuenta; el mensaje se muestra tal cual.
class AccountException implements Exception {
  AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Borrar la cuenta. El servidor (`deleteAccount` en functions/index.js) hace
/// todo el trabajo: revisa citas y pagos pendientes, borra los datos y, al
/// final, el usuario de Firebase Auth. La app solo lo llama y cierra sesión.
class AccountService {
  AccountService._();

  static Future<void> deleteAccount() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
        'deleteAccount',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      await callable.call<Object?>({'confirm': 'BORRAR'});
    } on FirebaseFunctionsException catch (e) {
      final msg = e.message ?? '';
      final technical = msg.isEmpty || msg == msg.toUpperCase() || msg.contains('INTERNAL');
      throw AccountException(
        technical ? 'No se pudo borrar tu cuenta. Inténtalo de nuevo.' : msg,
      );
    } catch (_) {
      throw AccountException('No hay conexión con el servidor. Revisa tu internet.');
    }
  }
}
