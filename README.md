# liveclothesshop_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## FashionStore CU10 multitenant

El catálogo existente requiere login de cliente con código de empresa; no hay
catálogo público de visitantes. `CatalogoApi` consulta `/api/catalogo/productos`,
detalle y facetas con Bearer de la sesión, sin enviar un `idEmp` seleccionable.
Las respuestas mantienen variantes, tallas, colores, precios y disponibilidad
por sucursal. La empresa y sus referencias se validan en el backend/RLS.

Lista y detalle aíslan su estado por identidad y estado de sesión: al cambiar
de cuenta/empresa se destruyen páginas, facetas y selección anteriores. Las
respuestas tardías no vuelven a mostrarlas. No se persiste catálogo en un caché
global ni se usan credenciales como claves de widgets. CU10 por sí solo no
habilita reservas, carrito ni pago; el bloque posterior CU11/CU12 se detalla abajo.

Para el backend local autorizado, usar `scripts/serve_test_api.py` del repositorio
API (puerto 8000; base exclusivamente `127.0.0.1:55432/fashionstore_test`). El
valor móvil predeterminado usa otro puerto: la configuración explícita es
`--dart-define=API_BASE_URL=http://127.0.0.1:8000`
y `--dart-define=API_ORIGIN=http://localhost:4200`. No colocar secretos en defines.
En Android se necesita un bridge de red específico; esa ejecución no está
acreditada en este bloque ni se debe cambiar el destino PostgreSQL para obtenerla.

Verificación desde este repositorio, sin actualizar dependencias:

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter doctor -v
```

En la continuación CU10: **49 pruebas Flutter aprobadas** y análisis sin
incidencias. Son tests Dart/widgets en host, no E2E móvil contra PostgreSQL ni
ejecución nativa. `flutter doctor` no encuentra Android SDK; solo lista
Windows/Chrome/Edge y advierte componentes C++ de Windows ausentes. No se instaló
SDK ni se compiló/desplegó una aplicación nativa. La evidencia y límites vigentes
se registran en la sección 12 de `../INFORME_INTEGRACION_SAAS_POST_AUDITORIA.md`.

## Reservas CU11 y carrito CU12

El runner local admite explícitamente reservas/carrito y el sandbox CU13–15
(sin cargos reales). Las pantallas descartan estado de la sesión anterior. La reserva
persiste su UUID antes de enviar y conserva aceptación (`nroReserva`), conflicto
o rechazo en Mis reservas. Una pendiente local no aparta stock del servidor.

`lib/core/offline_sync.dart` usa ahora **SQLite real**, con
`lib/core/offline_database.dart`, `sqflite` y FFI para pruebas host. Migra el JSON
legacy de forma transaccional, repetible y verificada, conservando UUID, contenido
y resultados; mantiene el original como copia de recuperación. Las credenciales
siguen en almacenamiento seguro, nunca en tablas de catálogo/ledger.

La lista de catálogo descarga explícitamente el subconjunto de sus filtros y
permite leerlo offline, indicando antigüedad; particiones por empresa/usuario.
`/caja` conecta descarga y venta en efectivo con SQLite, permiso CU24 y rol cajero,
UUID persistido antes del envío por sync; el servidor recalcula precios/stock.
No convierte al cliente en cajero. `/tienda/historial-compras` consulta el historial
online y conserva el precio histórico del servidor; no simula historial offline.

Suite actual: **71 tests host/widgets aprobados**, análisis sin incidencias.
Incluye rollback, dos conexiones SQLite, migración repetida, reinicio tras respuesta
perdida y sesión tardía/vencida. No acredita Android/iOS, background nativo ni
móvil real contra API. Trazabilidad CU18/CU19
documentales frente a CU11/CU12 técnicos y resultados acumulados en
`../EQUIVALENCIAS_RESERVAS_CARRITO.md` y sección 13 del informe de integración.
