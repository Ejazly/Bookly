import '../models/models.dart';

/// Negocios de ejemplo. La primera vez que alguien inicia sesión se guardan
/// en Firestore (con id "demo_...") para que la app no se vea vacía.
/// No tienen dueño real, así que sus citas no envían correo.
final List<Business> demoBusinesses = [
  const Business(
    id: 'demo_1',
    ownerUid: '',
    ownerEmail: '',
    name: 'Barbería El Clásico',
    category: BusinessCategory.barberias,
    address: 'Av. Universidad 120, Querétaro',
    phone: '4421234567',
    openHour: 10,
    closeHour: 20,
    closedWeekdays: {DateTime.sunday},
    professionals: ['Luis', 'Andrés'],
    rating: 4.8,
    demo: true,
    slogan: 'Cortes clásicos con estilo moderno',
    description: 'Barbería familiar con más de 10 años en Querétaro. '
        'Usamos toalla caliente y productos profesionales.',
    themeIndex: 6,
    instagram: 'barberiaelclasico',
  ),
  const Business(
    id: 'demo_2',
    ownerUid: '',
    ownerEmail: '',
    name: 'Estética Bella Luna',
    category: BusinessCategory.esteticas,
    address: 'Calle Zaragoza 45, Centro',
    phone: '4422345678',
    openHour: 9,
    closeHour: 19,
    closedWeekdays: {DateTime.sunday},
    professionals: ['Mariana', 'Sofía'],
    rating: 4.6,
    demo: true,
    slogan: 'Tu cambio de look empieza aquí',
    description: 'Especialistas en color, cortes y peinados para eventos.',
    themeIndex: 4,
  ),
  const Business(
    id: 'demo_3',
    ownerUid: '',
    ownerEmail: '',
    name: 'Spa Lirio',
    category: BusinessCategory.spas,
    address: 'Blvd. Bernardo Quintana 300',
    phone: '4423456789',
    openHour: 10,
    closeHour: 20,
    closedWeekdays: {DateTime.monday},
    professionals: ['Elena', 'Carla'],
    rating: 4.9,
    demo: true,
    slogan: 'Relájate, nosotros nos encargamos',
    description: 'Masajes, faciales y aromaterapia en un ambiente tranquilo.',
    themeIndex: 3,
    whatsapp: '4423456789',
  ),
];

/// Servicios y productos de cada negocio de ejemplo.
final Map<String, List<Item>> demoItems = {
  'demo_1': const [
    Item(id: '', kind: ItemKind.servicio, name: 'Corte clásico', price: 150, minutes: 45,
        description: 'Corte con máquina y tijera, incluye lavado.'),
    Item(id: '', kind: ItemKind.servicio, name: 'Corte + barba', price: 230, minutes: 60,
        description: 'Corte completo y arreglo de barba con toalla caliente.'),
    Item(id: '', kind: ItemKind.producto, name: 'Cera para cabello', price: 120, stock: 12,
        description: 'Fijación media, acabado mate. 100 g.'),
  ],
  'demo_2': const [
    Item(id: '', kind: ItemKind.servicio, name: 'Corte de dama', price: 250, minutes: 60,
        description: 'Corte, lavado y secado.'),
    Item(id: '', kind: ItemKind.servicio, name: 'Tinte completo', price: 650, minutes: 120,
        description: 'Incluye diagnóstico de color y tratamiento.'),
    Item(id: '', kind: ItemKind.producto, name: 'Shampoo sin sulfatos', price: 190, stock: 8,
        description: 'Ideal para cabello teñido. 400 ml.'),
  ],
  'demo_3': const [
    Item(id: '', kind: ItemKind.servicio, name: 'Masaje relajante', price: 400, minutes: 60,
        description: 'Masaje de cuerpo completo con aceites esenciales.'),
    Item(id: '', kind: ItemKind.servicio, name: 'Facial hidratante', price: 450, minutes: 60,
        description: 'Limpieza profunda e hidratación.'),
    Item(id: '', kind: ItemKind.producto, name: 'Aceite de lavanda', price: 160, stock: 2,
        description: 'Aceite esencial para aromaterapia. 30 ml.'),
  ],
};

/// Publicaciones de ejemplo para la sección Novedades.
final List<Post> demoPosts = [
  const Post(
    id: '',
    businessId: 'demo_1',
    businessName: 'Barbería El Clásico',
    category: BusinessCategory.barberias,
    text: 'Martes de estudiantes: 15 % de descuento en cualquier corte presentando tu credencial.',
  ),
  const Post(
    id: '',
    businessId: 'demo_3',
    businessName: 'Spa Lirio',
    category: BusinessCategory.spas,
    text: 'Estrenamos cabinas de masaje. Agenda esta semana y recibe aromaterapia gratis.',
  ),
];
