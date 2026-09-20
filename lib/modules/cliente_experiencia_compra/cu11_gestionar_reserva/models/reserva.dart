/// Modelos de CU11 Gestionar reserva (mismo contrato que `/api/cliente/reservas`).
class ReservaItem {
  const ReservaItem({
    required this.idDetalleRes,
    required this.idVar,
    required this.sku,
    required this.producto,
    required this.cantidad,
    this.imagen,
    this.talla,
    this.categoria,
    this.colores = const [],
  });

  final int idDetalleRes;
  final String idVar;
  final String sku;
  final String producto;
  final int cantidad;
  final String? imagen;
  final String? talla;
  final String? categoria;
  final List<String> colores;

  factory ReservaItem.fromJson(Map<String, dynamic> json) => ReservaItem(
    idDetalleRes: json['idDetalleRes'] as int? ?? 0,
    idVar: json['idVar']?.toString() ?? '',
    sku: json['sku']?.toString() ?? '',
    producto: json['producto']?.toString() ?? '',
    cantidad: json['cantidad'] as int? ?? 0,
    imagen: json['imagen']?.toString(),
    talla: json['talla']?.toString(),
    categoria: json['categoria']?.toString(),
    colores: (json['colores'] as List? ?? const [])
        .map((item) => item.toString())
        .where((nombre) => nombre.isNotEmpty)
        .toList(),
  );
}

class ReservaSucursal {
  const ReservaSucursal({
    required this.nro,
    required this.nombre,
    required this.ciudad,
  });

  final int nro;
  final String nombre;
  final String ciudad;

  factory ReservaSucursal.fromJson(Map<String, dynamic> json) =>
      ReservaSucursal(
        nro: json['nro'] as int? ?? 0,
        nombre: json['nombre']?.toString() ?? '',
        ciudad: json['ciudad']?.toString() ?? '',
      );
}

class Reserva {
  const Reserva({
    required this.nroReserva,
    required this.fechaReserva,
    required this.horaAtencion,
    required this.estado,
    required this.sucursal,
    required this.totalUnidades,
    this.items = const [],
    this.vencida = false,
  });

  final int nroReserva;
  final DateTime? fechaReserva;
  final String horaAtencion;
  final String estado;
  final ReservaSucursal sucursal;
  final int totalUnidades;
  final List<ReservaItem> items;
  final bool vencida;

  bool get puedeCancelarse => estado == 'pendiente' || estado == 'confirmada';

  factory Reserva.fromJson(Map<String, dynamic> json) => Reserva(
    nroReserva: json['nroReserva'] as int? ?? 0,
    fechaReserva: DateTime.tryParse(json['fechaReserva']?.toString() ?? ''),
    horaAtencion: json['horaAtencion']?.toString() ?? '',
    estado: json['estado']?.toString() ?? '',
    sucursal: ReservaSucursal.fromJson(
      (json['sucursal'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    totalUnidades: json['totalUnidades'] as int? ?? 0,
    items: (json['items'] as List? ?? const [])
        .map(
          (item) => ReservaItem.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
    vencida: json['vencida'] as bool? ?? false,
  );
}

class ReservasListado {
  const ReservasListado({
    this.items = const [],
    this.total = 0,
    this.offset = 0,
    this.limit = 20,
  });

  final List<Reserva> items;
  final int total;
  final int offset;
  final int limit;

  factory ReservasListado.fromJson(Map<String, dynamic> json) =>
      ReservasListado(
        items: (json['items'] as List? ?? const [])
            .map(
              (item) => Reserva.fromJson((item as Map).cast<String, dynamic>()),
            )
            .toList(),
        total: json['total'] as int? ?? 0,
        offset: json['offset'] as int? ?? 0,
        limit: json['limit'] as int? ?? 20,
      );
}

class SucursalCliente {
  const SucursalCliente({
    required this.nro,
    required this.nombre,
    required this.direccion,
    required this.ciudad,
  });

  final int nro;
  final String nombre;
  final String direccion;
  final String ciudad;

  factory SucursalCliente.fromJson(Map<String, dynamic> json) =>
      SucursalCliente(
        nro: json['nro'] as int? ?? 0,
        nombre: json['nombre']?.toString() ?? '',
        direccion: json['direccion']?.toString() ?? '',
        ciudad: json['ciudad']?.toString() ?? '',
      );
}

/// Rango horario declarado por la sucursal (`/api/cliente/sucursales/{nro}/horarios`).
class HorarioRango {
  const HorarioRango({required this.horaIni, required this.horaFin});

  final String horaIni;
  final String horaFin;

  factory HorarioRango.fromJson(Map<String, dynamic> json) => HorarioRango(
    horaIni: json['horaIni']?.toString() ?? '',
    horaFin: json['horaFin']?.toString() ?? '',
  );
}

class HorariosSucursal {
  const HorariosSucursal({required this.nroSuc, this.rangos = const []});

  final int nroSuc;
  final List<HorarioRango> rangos;

  factory HorariosSucursal.fromJson(Map<String, dynamic> json) =>
      HorariosSucursal(
        nroSuc: json['nroSuc'] as int? ?? 0,
        rangos: (json['rangos'] as List? ?? const [])
            .map(
              (item) =>
                  HorarioRango.fromJson((item as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
}
