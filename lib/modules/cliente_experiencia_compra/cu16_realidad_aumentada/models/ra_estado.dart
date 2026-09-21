import 'dart:ui' show Size;

import 'package:camera/camera.dart';

/// Estado del probador: qué está pasando entre la cámara y la pose (CU16).
enum RaEstadoPose {
  /// Aún no hay pose utilizable.
  buscando,

  /// Pose válida y polera en pantalla.
  activa,

  /// Hay cámara pero el torso no se ve con confianza suficiente.
  sinTorso,

  /// No hay cámara disponible (permiso, hardware o plataforma).
  sinCamara,
}

extension RaEstadoPoseMensaje on RaEstadoPose {
  /// Mensaje para el usuario (requisito de mensajes de CU16).
  String get mensaje => switch (this) {
    RaEstadoPose.buscando => 'Buscando tu postura…',
    RaEstadoPose.activa => 'Prueba virtual activa',
    RaEstadoPose.sinTorso => 'Asegúrate de que hombros y torso sean visibles.',
    RaEstadoPose.sinCamara => 'No se pudo acceder a la cámara.',
  };
}

/// Errores de cámara normalizados: nunca se muestra un error técnico crudo.
enum RaErrorCamara {
  /// El usuario rechazó el permiso en el diálogo.
  permisoDenegado,

  /// El permiso quedó bloqueado: hay que activarlo en los ajustes.
  permisoBloqueado,

  /// Control parental u otra restricción del sistema.
  restringido,

  /// El dispositivo no reporta cámaras utilizables.
  sinCamara,

  /// Plataforma no soportada (web/escritorio).
  noSoportado,

  /// La variante elegida no tiene imagen para probar.
  sinImagen,

  /// Cualquier otro fallo de la cámara.
  desconocido,
}

extension RaErrorCamaraMensaje on RaErrorCamara {
  String get mensaje => switch (this) {
    RaErrorCamara.permisoDenegado =>
      'Necesitamos acceso a la cámara para utilizar el probador virtual.',
    RaErrorCamara.permisoBloqueado =>
      'El permiso de cámara está bloqueado. Actívalo en los ajustes del '
          'sistema para utilizar el probador virtual.',
    RaErrorCamara.restringido =>
      'El acceso a la cámara está restringido en este dispositivo.',
    RaErrorCamara.sinCamara => 'No se pudo acceder a la cámara.',
    RaErrorCamara.noSoportado =>
      'El probador virtual está disponible actualmente en dispositivos '
          'móviles compatibles.',
    RaErrorCamara.sinImagen =>
      'Esta variante todavía no tiene una imagen para el probador virtual.',
    RaErrorCamara.desconocido => 'No se pudo acceder a la cámara.',
  };

  /// Si conviene ofrecer un botón para abrir los ajustes del sistema.
  bool get ofreceAjustes =>
      this == RaErrorCamara.permisoDenegado ||
      this == RaErrorCamara.permisoBloqueado;
}

/// Estado de la cámara del probador.
class CamaraRaEstado {
  const CamaraRaEstado({
    this.controlador,
    this.descripcion,
    this.preparando = false,
    this.error,
  });

  const CamaraRaEstado.preparando()
    : controlador = null,
      descripcion = null,
      preparando = true,
      error = null;

  const CamaraRaEstado.error(RaErrorCamara motivo)
    : controlador = null,
      descripcion = null,
      preparando = false,
      error = motivo;

  final CameraController? controlador;
  final CameraDescription? descripcion;
  final bool preparando;
  final RaErrorCamara? error;

  bool get lista => controlador?.value.isInitialized ?? false;

  /// Tamaño del preview tal como lo entrega el plugin (orientación del sensor).
  Size get tamanoPreview => controlador?.value.previewSize ?? Size.zero;

  /// Rotación del sensor: 90/270 obligan a intercambiar ancho y alto.
  int get orientacionSensor => descripcion?.sensorOrientation ?? 90;

  /// CU16 prioriza la cámara frontal.
  bool get esFrontal => descripcion?.lensDirection == CameraLensDirection.front;

  bool get hayCamara => controlador != null && error == null;
}
