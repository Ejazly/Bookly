import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/email_config.dart';
import '../models/models.dart';
import '../utils/format.dart';

/// Envía correos de aviso a través de EmailJS.
///
/// EmailJS usa una plantilla con 4 variables:
///   {{to_email}}  correo de quien recibe
///   {{to_name}}   nombre de quien recibe
///   {{subject}}   asunto
///   {{message}}   texto del aviso
/// Así una sola plantilla sirve para todos los avisos.
class EmailService {
  static const String _endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  static bool get isConfigured => EmailConfig.isConfigured;

  /// Regresa true si EmailJS aceptó el correo.
  /// Nunca lanza errores: si algo falla, la cita igual queda guardada.
  static Future<bool> send({
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
  }) async {
    if (!isConfigured || toEmail.trim().isEmpty) return false;
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': EmailConfig.serviceId,
              'template_id': EmailConfig.templateId,
              'user_id': EmailConfig.publicKey,
              'template_params': {
                'to_email': toEmail.trim(),
                'to_name': toName,
                'subject': subject,
                'message': message,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _when(Appointment a) =>
      '${longDate(a.start)} a las ${hhmm(a.start)}';

  /// Aviso al negocio: un cliente agendó desde la app.
  static Future<bool> notifyNewBooking(Appointment a) {
    final contact = [
      a.clientEmail,
      if (a.clientPhone.isNotEmpty) a.clientPhone,
    ].join(' · ');
    return send(
      toEmail: a.ownerEmail,
      toName: a.businessName,
      subject: 'Nueva cita: ${a.clientName} – ${shortDate(a.start)} ${hhmm(a.start)}',
      message: '${a.clientName} agendó una cita en ${a.businessName}.\n\n'
          'Servicio: ${a.serviceName} (${durationText(a.minutes)})\n'
          'Fecha: ${_when(a)}\n'
          'Atiende: ${a.professional}\n'
          'Anticipo pagado: ${money2(a.depositPaid)}\n'
          'Restante a cobrar en el negocio: ${money2(a.remaining)}\n'
          'Contacto del cliente: $contact'
          '${a.note.isNotEmpty ? '\nNota del cliente: ${a.note}' : ''}',
    );
  }

  /// Aviso al negocio: el cliente canceló.
  static Future<bool> notifyCancelledByClient(Appointment a) {
    return send(
      toEmail: a.ownerEmail,
      toName: a.businessName,
      subject: 'Cita cancelada: ${a.clientName} – ${shortDate(a.start)} ${hhmm(a.start)}',
      message: '${a.clientName} canceló su cita de ${a.serviceName} '
          'del ${_when(a)} con ${a.professional}.\n'
          'Ese horario vuelve a estar disponible en tu agenda.',
    );
  }

  /// Aviso al negocio: el cliente cambió el horario.
  static Future<bool> notifyRescheduled(Appointment before, Appointment after) {
    return send(
      toEmail: after.ownerEmail,
      toName: after.businessName,
      subject: 'Cita reprogramada: ${after.clientName}',
      message: '${after.clientName} cambió su cita de ${after.serviceName}.\n\n'
          'Antes: ${_when(before)} con ${before.professional}\n'
          'Ahora: ${_when(after)} con ${after.professional}',
    );
  }

  /// Aviso al cliente: el negocio lo agregó a su agenda.
  static Future<bool> notifyClientAdded(Appointment a) {
    return send(
      toEmail: a.clientEmail,
      toName: a.clientName,
      subject: 'Tu cita en ${a.businessName} – ${shortDate(a.start)} ${hhmm(a.start)}',
      message: '${a.businessName} te agendó una cita.\n\n'
          'Servicio: ${a.serviceName}\n'
          'Fecha: ${_when(a)}\n'
          'Te atiende: ${a.professional}\n'
          '${a.depositPaid > 0 ? 'Anticipo registrado: ${money2(a.depositPaid)} · Restante: ${money2(a.remaining)}' : 'Costo: ${money2(a.price)} (se paga en el negocio)'}\n\n'
          'Si inicias sesión en Bookly con este correo verás la cita en "Mis citas".',
    );
  }

  /// Aviso al cliente: el negocio canceló la cita.
  static Future<bool> notifyCancelledByBusiness(Appointment a) {
    return send(
      toEmail: a.clientEmail,
      toName: a.clientName,
      subject: 'Tu cita en ${a.businessName} fue cancelada',
      message: '${a.businessName} canceló tu cita de ${a.serviceName} '
          'del ${_when(a)}.\n'
          '${a.depositPaid > 0 && !a.createdByBusiness ? 'Tu anticipo de ${money2(a.depositPaid)} se te devolvió a tu tarjeta (puede tardar de 5 a 10 días en verse).' : 'Si quieres otra fecha, puedes agendar de nuevo en Bookly.'}',
    );
  }

  /// Aviso al negocio: alguien compró un producto (ya pagado).
  static Future<bool> notifyNewOrder(ShopOrder o) {
    return send(
      toEmail: o.ownerEmail,
      toName: o.businessName,
      subject: 'Nueva venta: ${o.quantity} × ${o.itemName}',
      message: '${o.buyerName} compró ${o.quantity} × ${o.itemName} en ${o.businessName}.\n\n'
          'Total pagado en línea: ${money2(fromCents(o.totalCents))}\n'
          'Correo del cliente: ${o.buyerEmail}\n'
          'Pasará a recoger su pedido al negocio. '
          'Lo verás también en Cuenta → Cobros y ventas.',
    );
  }
}
