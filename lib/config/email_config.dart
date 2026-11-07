// Datos de tu cuenta de EmailJS (servicio gratuito que envía los correos
// de aviso desde tu Gmail). Ver la guía FIREBASE_Y_CORREO.md, paso 6.
//
// Mientras sigan diciendo PEGA_AQUI la app funciona igual, solo que no
// envía correos (muestra un aviso en pantalla).

class EmailConfig {
  /// EmailJS → Email Services → tu servicio de Gmail → "Service ID".
  static const String serviceId = 'PEGA_AQUI_serviceId';

  /// EmailJS → Email Templates → tu plantilla → "Template ID".
  static const String templateId = 'PEGA_AQUI_templateId';

  /// EmailJS → Account → General → "Public Key".
  static const String publicKey = 'PEGA_AQUI_publicKey';

  static bool get isConfigured =>
      !serviceId.startsWith('PEGA_AQUI') &&
      !templateId.startsWith('PEGA_AQUI') &&
      !publicKey.startsWith('PEGA_AQUI');
}
