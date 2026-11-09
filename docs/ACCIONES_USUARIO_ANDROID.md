# Acciones requeridas del usuario — Android (CU23 y CU27)

**Fecha:** 2026-11-08
**Producto:** FashionStore
**Estado:** BLOQUEADO — requiere intervención humana para instalar el SDK de Android y aceptar licencias.

## 1. Resumen del bloqueo

No se encuentra el SDK de Android en el equipo. Las herramientas de línea de comandos `adb`, `emulator`, `sdkmanager` no están instaladas, y las variables de entorno `ANDROID_HOME` / `ANDROID_SDK_ROOT` no están definidas. Por consiguiente:

- **CU23 (vestidor virtual AR documental):** no se puede compilar ni instalar la aplicación móvil en dispositivo/emulador, por lo que no se puede verificar permisos de cámara, seguimiento/anclaje AR, ni liberación de recursos en un dispositivo real.
- **CU27 (venta presencial offline móvil):** no se puede ejecutar la aplicación móvil nativa contra la API de pruebas, verificar SQLite como cola activa en dispositivo, ni probar la coordinación de Workmanager en segundo plano.

Ambos casos de uso quedan como **bloqueados** hasta que se instale el SDK de Android y se disponga de un dispositivo o emulador.

## 2. Pasos exactos para el usuario

### 2.1 Instalar Android SDK (command-line tools)

1. Descargar "Android SDK Command-line Tools" para Windows desde:
   https://developer.android.com/studio#command-tools
2. Descomprimir en una carpeta local (por ejemplo: `C:\Android\cmdline-tools`).
3. La estructura esperada es: `<carpeta>/cmdline-tools/bin/sdkmanager.bat`

### 2.2 Aceptar licencias e instalar componentes

Abrir PowerShell en la carpeta del SDK y ejecutar:

```powershell
$env:ANDROID_HOME="C:\Android"
$env:ANDROID_SDK_ROOT="C:\Android"
# Instalar platform-tools, emulator, build-tools y una imagen de sistema
& "$env:ANDROID_HOME\cmdline-tools\bin\sdkmanager.bat" "platform-tools" "emulator" "build-tools;34.0.0" "platforms;android-34" "system-images;android-34;google_apis;x86_64"
# Aceptar todas las licencias cuando se solicite
& "$env:ANDROID_HOME\cmdline-tools\bin\sdkmanager.bat" --licenses
```

**Nota:** El paso de `--licenses` requiere intervención humana para leer y aceptar cada licencia de los componentes de Google/Android. El agente no puede aceptar licencias en nombre del usuario.

### 2.3 Crear un dispositivo virtual (emulador)

```powershell
& "$env:ANDROID_HOME\cmdline-tools\bin\avdmanager.bat" create avd -n fashionstore_test -k "system-images;android-34;google_apis;x86_64" -g google_apis
```

Iniciar el emulador:

```powershell
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd fashionstore_test &
```

### 2.4 Verificar conexión con `adb`

```powershell
$env:ANDROID_HOME="C:\Android"
& "$env:ANDROID_HOME\platform-tools\adb.exe" devices
```

Se debe ver el dispositivo/emulador listado como `device`.

### 2.5 Compilar e instalar la aplicación móvil

Desde `C:\SI2_Parcial1\liveclothesshop_mobile`:

```powershell
$env:ANDROID_HOME="C:\Android"
flutter pub get
flutter build apk --debug
flutter install
```

O ejecutar en el emulador directamente:

```powershell
flutter run
```

### 2.6 Conectar a la API de pruebas

Desde el dispositivo/emulador, la API debe ser alcanzable en la dirección de host del PC (no `localhost`/`127.0.0.1` del emulador). Configurar `API_BASE_URL` en `lib/core/api_config.dart` con la IP del PC en la red local (por ejemplo `http://192.168.x.x:8000`), no el loopback del emulador.

## 3. Qué se verificará una vez desbloqueado

### CU23 — Vestidor virtual AR
- Permisos de cámara concedidos en el dispositivo.
- Comprobación de compatibilidad AR (ARCore disponible).
- Selección de prenda desde el catálogo de la empresa y obtención de recurso 3D.
- Seguimiento/anclaje y visualización en tiempo real sobre la persona.
- Manejo de recurso ausente, cámara denegada e incompatibilidad.
- Liberación correcta de cámara y recursos al salir.
- Ninguna mutación de inventario por probar prendas.

### CU27 — Venta presencial offline móvil
- Rol de cajero autorizado y sucursal válida requeridos para la caja offline.
- Catálogo, reservas, ventas de contado, detalles y resultados persisten en SQLite tras reiniciar.
- UUID estable por operación, aislado por empresa y usuario.
- Sincronización sin duplicados, conservación de conflictos y rechazos.
- Diferenciación entre sesión vencida y fallo de red.
- Coordinación de Workmanager y primer plano.
- Una operación offline registrada, cerrado/reabierto el ejército, reconectado y verificado en PostgreSQL (efectos SQL únicos).

## 4. Archivos del proyecto relacionados

- `liveclothesshop_mobile/lib/core/offline_database.dart` — cola SQLite activa.
- `liveclothesshop_mobile/lib/core/offline_sync.dart` — sincronización y replay.
- `liveclothesshop_mobile/lib/core/session.dart` — gestión de sesión y tenant.
- `liveclothesshop_mobile/lib/modules/` — pantallas de cliente, caja y reservas.
- `pubspec.yaml` — dependencias (sqflite, workmanager, etc.).

## 5. Estado actual

| Elemento | Estado |
|---|---|
| Android SDK | ❌ No instalado |
| adb / emulator | ❌ No disponibles |
| Dispositivo/emulador | ❌ No conectado |
| Licencias aceptadas | ❌ Pendiente de intervención humana |
| Compilación móvil nativa | ❌ Bloqueada |
| Ejecución contra API local | ❌ Bloqueada |

## 6. Siguiente acción

Una vez instalado el SDK y aceptadas las licencias, ejecutar:
1. `flutter doctor -v` para verificar detección de Android.
2. `flutter run` en el emulador conectado a la API en `127.0.0.1:8000` (o IP del PC).
3. Verificar operación offline, cierre/reapertura, sincronización y efectos en PostgreSQL.
