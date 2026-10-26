import 'package:flutter/material.dart';

/// Porcentaje del costo que se paga por adelantado al reservar.
const double depositRate = 0.25;

/// Calcula el anticipo (25 %) redondeado a centavos.
double depositFor(double price) =>
    (price * depositRate * 100).roundToDouble() / 100;

/// Un servicio que ofrece un negocio (ej. "Corte + barba").
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.minutes,
    required this.price,
  });

  final String id;
  final String name;
  final int minutes; // duración
  final double price;

  double get deposit => depositFor(price);
}

/// Persona que atiende en el negocio (barbero, estilista, etc.).
class Professional {
  const Professional({required this.id, required this.name});

  final String id;
  final String name;
}

/// Reseña de un cliente.
class Review {
  const Review(this.author, this.stars, this.text);

  final String author;
  final int stars;
  final String text;
}

enum BusinessCategory { barberias, esteticas, spas, unas }

extension BusinessCategoryInfo on BusinessCategory {
  String get label => switch (this) {
        BusinessCategory.barberias => 'Barberías',
        BusinessCategory.esteticas => 'Estéticas',
        BusinessCategory.spas => 'Spas',
        BusinessCategory.unas => 'Uñas',
      };

  IconData get icon => switch (this) {
        BusinessCategory.barberias => Icons.content_cut,
        BusinessCategory.esteticas => Icons.face_retouching_natural,
        BusinessCategory.spas => Icons.spa,
        BusinessCategory.unas => Icons.brush,
      };
}

/// Un negocio registrado en Bookly.
class Business {
  const Business({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.distanceKm,
    required this.rating,
    required this.reviewCount,
    required this.openHour,
    required this.closeHour,
    required this.closedWeekdays,
    required this.services,
    required this.professionals,
    required this.colors,
    required this.videoCaption,
    this.reviews = const [],
    this.promo,
  });

  final String id;
  final String name;
  final BusinessCategory category;
  final String address;
  final double distanceKm;
  final double rating;
  final int reviewCount;
  final int openHour; // ej. 10 = 10:00
  final int closeHour; // ej. 20 = 20:00
  final Set<int> closedWeekdays; // DateTime.sunday, DateTime.monday...
  final List<Service> services;
  final List<Professional> professionals;
  final List<Color> colors; // colores para las imágenes de ejemplo
  final String videoCaption;
  final List<Review> reviews;
  final String? promo;

  bool isOpenOn(DateTime day) => !closedWeekdays.contains(day.weekday);

  bool isOpenAt(DateTime moment) =>
      isOpenOn(moment) &&
      moment.hour >= openHour &&
      moment.hour < closeHour;

  double get minPrice {
    var min = services.first.price;
    for (final s in services) {
      if (s.price < min) min = s.price;
    }
    return min;
  }
}

enum AppointmentStatus { confirmada, cancelada }

/// Una cita agendada.
class Appointment {
  Appointment({
    required this.id,
    required this.business,
    required this.service,
    required this.professional,
    required this.start,
    required this.clientName,
    this.note = '',
    this.depositPaid = 0,
    this.fromCurrentUser = false,
    this.status = AppointmentStatus.confirmada,
  });

  final String id;
  final Business business;
  final Service service;
  Professional professional; // puede cambiar al reprogramar
  DateTime start; // puede cambiar al reprogramar
  final String clientName;
  final String note;
  final double depositPaid;
  final bool fromCurrentUser; // true = la hizo la usuaria de la app
  AppointmentStatus status;

  DateTime get end => start.add(Duration(minutes: service.minutes));
  double get remaining => service.price - depositPaid;
  bool get isCancelled => status == AppointmentStatus.cancelada;
}
