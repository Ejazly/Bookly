# Guía: formulario "Seguridad de los datos" de Google Play

Respuestas sugeridas basadas en el código actual de Bookly. Lo marcado con ⚠ debe confirmarlo la autora antes de enviar el formulario. Si algo cambia en la app, hay que actualizar el formulario.

## 1. Preguntas generales

| Pregunta | Respuesta | Base en el código |
|---|---|---|
| ¿La app recopila o comparte datos de usuario? | **Sí** | Firebase, Stripe, EmailJS, AdMob |
| ¿Todos los datos se cifran en tránsito? | **Sí** | Firebase, Stripe, EmailJS (`https://api.emailjs.com`), Nominatim y teselas usan HTTPS. ⚠ Confirma que no queda ninguna URL `http://` en `lib/` |
| ¿Ofreces forma de pedir que se borren los datos? | **Sí** | Perfil → Borrar mi cuenta. ⚠ **Aún no existe en el código al escribir esto** (el ROADMAP lo marca pendiente); confirma que esté implementada antes de responder Sí. Además, requiere enlace web (correo de contacto o página) |
| ¿Cumple la política de Familias? | No aplica | La app no está dirigida a niños |
| URL de política de privacidad | ⚠ Publicar `PRIVACIDAD.md` en una URL pública (por ejemplo, GitHub Pages o un Google Doc público) y pegar el enlace | |

## 2. Casilla "Contiene anuncios"
**Sí.** AdMob (`google_mobile_ads`) en Android: banner en Inicio y anuncios en Novedades, solo clasificación G (`lib/ads/ads_mobile.dart`). ⚠ Cambiar los IDs de prueba (`lib/config/ads_config.dart` y `AndroidManifest.xml`) por los de tu cuenta de AdMob.

## 3. Tipos de datos

Convención: "Recopilado" = sale del dispositivo hacia ti o tus proveedores. "Compartido" = se transfiere a un tercero que no es solo procesador de servicio (Google define que pasar datos a un proveedor que los procesa en tu nombre, como Firebase, **no** cuenta como "compartir").

### Información personal
| Dato | ¿Recopilado? | ¿Compartido? | Obligatorio/Opcional | Finalidad |
|---|---|---|---|---|
| Nombre | Sí | No (ver nota EmailJS) | Obligatorio | Funciones de la app, gestión de cuenta |
| Correo electrónico | Sí | No | Obligatorio | Funciones de la app, gestión de cuenta, comunicaciones |
| ID de usuario (uid) | Sí | No | Obligatorio | Funciones de la app, gestión de cuenta |
| Número de teléfono | Sí (teléfono del cliente en la cita y del negocio) | No | Opcional | Funciones de la app |
| Dirección (del negocio) | Sí | No | Opcional | Funciones de la app |

⚠ Foto de perfil de Google: **no encontré en el código** que se lea o guarde. Si no se usa, no la declares. En `PRIVACIDAD.md` está mencionada con "si la app la muestra": confirma o quítala.

### Información financiera
| Dato | Respuesta |
|---|---|
| Información de pago (número de tarjeta) | **No recopilada por la app.** Se captura en Stripe Checkout (página de Stripe). Google acepta no declararla si la app no la ve. ⚠ Confirma que usas Checkout alojado por Stripe |
| Historial de compras | **Sí** recopilado (citas, pedidos, movimientos en la billetera). Funciones de la app. No compartido |
| Otra información financiera | Sí: marca y últimos 4 dígitos de tarjeta guardada, montos de anticipos/comisiones. Funciones de la app |

### Ubicación
| Dato | Respuesta |
|---|---|
| Ubicación aproximada y precisa | La app la lee (permisos `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION`) para "Cerca de ti" y **no la guarda ni la envía al servidor** (`lib/services/location_service.dart`). Según Google, los datos que solo se procesan en el dispositivo **no cuentan como recopilados**, por tanto **no se declara**. ⚠ Confírmalo: ANUNCIOS.md sugiere declarar "ubicación aproximada"; ⚠ AdMob puede inferir ubicación aproximada por IP, y esa parte la cubre la declaración de AdMob |

### Fotos y videos
| Dato | Respuesta |
|---|---|
| Fotos | **Sí** recopiladas (logo, portada, galería, productos, publicaciones, subidas por el negocio). Opcional. Funciones de la app. No compartidas |
| Videos | **Sí** recopilados (publicaciones, Firebase Storage). Opcional. Funciones de la app |

### Mensajes / Contenido de la app
| Dato | Respuesta |
|---|---|
| Otros contenidos generados por el usuario | **Sí**: descripciones, notas de la cita, publicaciones. Funciones de la app |

### Actividad en la app / Información del dispositivo
| Dato | Respuesta |
|---|---|
| ID de dispositivo u otros ID (ID de publicidad) | **Sí, compartido con AdMob** (publicidad o marketing). Obligatorio (no se puede desactivar dentro de la app) |
| Interacciones con la app, diagnósticos | ⚠ Solo si el SDK de AdMob los recopila; consulta la guía oficial de Google para AdMob (https://support.google.com/admob/answer/10101885). Declara lo que ahí se indica para el uso de anuncios. No hay Analytics ni Crashlytics en el proyecto ⚠ (confirmar en `pubspec.yaml`) |

### No recopila
Contactos, calendario, mensajes SMS, salud y estado físico, audio, archivos y documentos, navegación web.

## 4. Cifrado y borrado (resumen para marcar)
- **Cifrado en tránsito:** Sí.
- **Solicitud de borrado:** Sí, desde la app (Perfil → Borrar mi cuenta) y por correo. ⚠ Ver arriba.
- Google también pide indicar si el usuario puede pedir borrado de **parte** de los datos: puedes borrar publicaciones, fotos y servicios desde el panel de negocio ⚠ confirmar.

## 5. Puntos que la autora debe confirmar
1. ⚠ Que exista "Borrar mi cuenta" funcionando y un enlace web de borrado (Play lo exige).
2. ⚠ URL pública de la política de privacidad.
3. ⚠ Foto de perfil de Google: ¿se usa o no?
4. ⚠ Ubicación: no se declara porque no sale del teléfono; confirma que es así.
5. ⚠ IDs de AdMob reales y categorías bloqueadas en AdMob.
6. ⚠ Paquete definitivo: hoy `applicationId` es `com.example.bookly` (Play no acepta `com.example`).
7. ⚠ Que ningún SDK extra (Analytics, Crashlytics, push) se haya agregado.
8. ⚠ Revisar la guía oficial de AdMob para declarar los datos del SDK de anuncios.
