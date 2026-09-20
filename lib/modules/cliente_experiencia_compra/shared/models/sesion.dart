/// Sesión del cliente autenticado (CU01/CU02). Refleja `AuthResponse` del
/// backend: `{usuario: {idUsuario, tipo, nombres, correo}, rol, permisos, expiraEn}`.
class UsuarioSesion {
  const UsuarioSesion({
    required this.idUsuario,
    required this.correo,
    this.nombres,
    this.tipo,
  });

  final String idUsuario;
  final String correo;
  final String? nombres;
  final String? tipo;

  String get nombreMostrado =>
      (nombres?.trim().isNotEmpty ?? false) ? nombres!.trim() : correo;

  factory UsuarioSesion.fromJson(Map<String, dynamic> json) => UsuarioSesion(
    idUsuario: json['idUsuario']?.toString() ?? '',
    correo: json['correo']?.toString() ?? '',
    nombres: json['nombres']?.toString() ?? json['nombre']?.toString(),
    tipo: json['tipo']?.toString(),
  );
}

class RolSesion {
  const RolSesion({required this.nro, required this.descripcion});

  final String nro;
  final String descripcion;

  factory RolSesion.fromJson(Map<String, dynamic> json) => RolSesion(
    nro: json['nro']?.toString() ?? '',
    descripcion: json['descripcion']?.toString() ?? '',
  );
}

class Sesion {
  const Sesion({
    required this.usuario,
    required this.rol,
    required this.permisos,
    this.expiraEn,
  });

  final UsuarioSesion usuario;
  final RolSesion rol;
  final List<String> permisos;
  final DateTime? expiraEn;

  bool get esCliente => usuario.tipo == null || usuario.tipo == 'C';

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
    usuario: UsuarioSesion.fromJson(
      (json['usuario'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    rol: RolSesion.fromJson(
      (json['rol'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    permisos:
        (json['permisos'] as List?)?.map((item) => item.toString()).toList() ??
        const [],
    expiraEn: DateTime.tryParse(json['expiraEn']?.toString() ?? '')?.toLocal(),
  );
}
