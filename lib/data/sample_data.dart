import 'package:flutter/material.dart';

import '../models/models.dart';

/// Negocios de ejemplo. Más adelante estos datos vendrán de Cloud Firestore.
final List<Business> sampleBusinesses = [
  Business(
    id: 'b1',
    name: 'Barbería El Clásico',
    category: BusinessCategory.barberias,
    address: 'Av. Universidad 120, Querétaro',
    distanceKm: 1.2,
    rating: 4.8,
    reviewCount: 214,
    openHour: 10,
    closeHour: 20,
    closedWeekdays: {DateTime.sunday},
    services: const [
      Service(id: 'b1s1', name: 'Corte clásico', minutes: 45, price: 150),
      Service(id: 'b1s2', name: 'Corte + barba', minutes: 60, price: 230),
      Service(id: 'b1s3', name: 'Afeitado con toalla', minutes: 30, price: 120),
    ],
    professionals: const [
      Professional(id: 'b1p1', name: 'Luis'),
      Professional(id: 'b1p2', name: 'Andrés'),
    ],
    colors: const [Color(0xFF2A7D89), Color(0xFF0F4450)],
    promo: 'Martes de estudiantes: 15 % de descuento con credencial',
    videoCaption:
        'Así queda un degradado bajo en 45 minutos. ¡Agenda tu corte desde Bookly!',
    reviews: const [
      Review('Mario R.', 5, 'Excelente corte y muy puntuales con la cita.'),
      Review('José P.', 5, 'Me gustó poder apartar con anticipo, cero filas.'),
      Review('Carlos M.', 4, 'Buen servicio, el lugar es pequeño pero cómodo.'),
    ],
  ),
  Business(
    id: 'b2',
    name: 'Estética Bella Luna',
    category: BusinessCategory.esteticas,
    address: 'Calle Zaragoza 45, Centro',
    distanceKm: 2.0,
    rating: 4.6,
    reviewCount: 158,
    openHour: 9,
    closeHour: 19,
    closedWeekdays: {DateTime.sunday},
    services: const [
      Service(id: 'b2s1', name: 'Corte de dama', minutes: 60, price: 250),
      Service(id: 'b2s2', name: 'Tinte completo', minutes: 120, price: 650),
      Service(id: 'b2s3', name: 'Peinado para evento', minutes: 60, price: 300),
    ],
    professionals: const [
      Professional(id: 'b2p1', name: 'Mariana'),
      Professional(id: 'b2p2', name: 'Sofía'),
    ],
    colors: const [Color(0xFFB37FA8), Color(0xFF1C6470)],
    videoCaption: 'Antes y después de un balayage miel. ¡Reserva tu cambio de look!',
    reviews: const [
      Review('Laura G.', 5, 'Mariana entendió perfecto el tono que quería.'),
      Review('Diana S.', 4, 'Muy bonito resultado, tardó un poco más de lo indicado.'),
    ],
  ),
  Business(
    id: 'b3',
    name: 'Spa Lirio',
    category: BusinessCategory.spas,
    address: 'Blvd. Bernardo Quintana 300',
    distanceKm: 3.4,
    rating: 4.9,
    reviewCount: 302,
    openHour: 10,
    closeHour: 20,
    closedWeekdays: {DateTime.monday},
    services: const [
      Service(id: 'b3s1', name: 'Masaje relajante', minutes: 60, price: 400),
      Service(id: 'b3s2', name: 'Facial hidratante', minutes: 60, price: 450),
      Service(id: 'b3s3', name: 'Manicure spa', minutes: 45, price: 200),
    ],
    professionals: const [
      Professional(id: 'b3p1', name: 'Elena'),
      Professional(id: 'b3p2', name: 'Carla'),
    ],
    colors: const [Color(0xFF43B376), Color(0xFF1C6470)],
    promo: '2x1 en manicure spa toda esta semana',
    videoCaption:
        'Conoce nuestras nuevas cabinas de masaje. Agenda hoy y recibe aromaterapia gratis.',
    reviews: const [
      Review('Fernanda T.', 5, 'El mejor masaje que me han dado en Querétaro.'),
      Review('Ana M.', 5, 'Instalaciones muy limpias y personal amable.'),
    ],
  ),
  Business(
    id: 'b4',
    name: 'Uñas Coral',
    category: BusinessCategory.unas,
    address: 'Plaza Juriquilla, local 12',
    distanceKm: 5.1,
    rating: 4.7,
    reviewCount: 96,
    openHour: 11,
    closeHour: 19,
    closedWeekdays: {DateTime.sunday},
    services: const [
      Service(id: 'b4s1', name: 'Gelish en manos', minutes: 60, price: 280),
      Service(id: 'b4s2', name: 'Uñas acrílicas', minutes: 90, price: 450),
      Service(id: 'b4s3', name: 'Pedicure', minutes: 60, price: 320),
    ],
    professionals: const [
      Professional(id: 'b4p1', name: 'Paola'),
    ],
    colors: const [Color(0xFFE38B6F), Color(0xFF1C6470)],
    videoCaption: 'Diseños de temporada: uñas otoñales en tonos terracota.',
    reviews: const [
      Review('Valeria H.', 5, 'Me duraron tres semanas perfectas.'),
    ],
  ),
];
