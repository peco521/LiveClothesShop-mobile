// Modelos CU11: reflejan el JSON de /api/cliente/reservas sin inventar atributos.

class ReservaItemCrear {
  final String idVar;
  final int cantidad;

  const ReservaItemCrear({required this.idVar, required this.cantidad});

  Map<String, dynamic> toJson() => {'idVar': idVar, 'cantidad': cantidad};
}

class ReservaCrear {
  final int nroSuc;
  final String fechaReserva;
  final String horaAtencion;
  final List<ReservaItemCrear> items;

  const ReservaCrear({
    required this.nroSuc,
    required this.fechaReserva,
    required this.horaAtencion,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'nroSuc': nroSuc,
        'fechaReserva': fechaReserva,
        'horaAtencion': horaAtencion,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class ReservaItem {
  final int idDetalle;
  final String idVar;
  final String sku;
  final String producto;
  final int cantidad;

  const ReservaItem({
    required this.idDetalle,
    required this.idVar,
    required this.sku,
    required this.producto,
    required this.cantidad,
  });

  factory ReservaItem.fromJson(Map<String, dynamic> json) => ReservaItem(
        idDetalle: (json['idDetalleRes'] as num).toInt(),
        idVar: json['idVar'] as String,
        sku: json['sku'] as String,
        producto: json['producto'] as String,
        cantidad: (json['cantidad'] as num).toInt(),
      );
}

class ReservaSucursal {
  final int nro;
  final String nombre;
  final String ciudad;

  const ReservaSucursal({required this.nro, required this.nombre, required this.ciudad});

  factory ReservaSucursal.fromJson(Map<String, dynamic> json) => ReservaSucursal(
        nro: (json['nro'] as num).toInt(),
        nombre: json['nombre'] as String,
        ciudad: json['ciudad'] as String,
      );
}

class ReservaDetalle {
  final int nroReserva;
  final String fecha;
  final String hora;
  final String estado;
  final ReservaSucursal sucursal;
  final List<ReservaItem> items;
  final int totalUnidades;
  final bool vencida;

  const ReservaDetalle({
    required this.nroReserva,
    required this.fecha,
    required this.hora,
    required this.estado,
    required this.sucursal,
    required this.items,
    required this.totalUnidades,
    required this.vencida,
  });

  bool get cancelable => estado == 'pendiente' && !vencida;

  factory ReservaDetalle.fromJson(Map<String, dynamic> json) => ReservaDetalle(
        nroReserva: (json['nroReserva'] as num).toInt(),
        fecha: json['fechaReserva'] as String,
        hora: json['horaAtencion'] as String,
        estado: json['estado'] as String,
        sucursal: ReservaSucursal.fromJson(json['sucursal'] as Map<String, dynamic>),
        items: ((json['items'] as List? ?? []).map((e) => ReservaItem.fromJson(e as Map<String, dynamic>))).toList(),
        totalUnidades: (json['totalUnidades'] as num).toInt(),
        vencida: json['vencida'] as bool? ?? false,
      );
}

class ReservasListado {
  final List<ReservaDetalle> items;
  final int total;

  const ReservasListado({required this.items, required this.total});

  factory ReservasListado.fromJson(Map<String, dynamic> json) => ReservasListado(
        items: ((json['items'] as List? ?? []).map((e) => ReservaDetalle.fromJson(e as Map<String, dynamic>))).toList(),
        total: (json['total'] as num).toInt(),
      );
}

class SucursalCliente {
  final int nro;
  final String nombre;
  final String direccion;
  final String ciudad;

  const SucursalCliente({required this.nro, required this.nombre, required this.direccion, required this.ciudad});

  factory SucursalCliente.fromJson(Map<String, dynamic> json) => SucursalCliente(
        nro: (json['nro'] as num).toInt(),
        nombre: json['nombre'] as String,
        direccion: json['direccion'] as String,
        ciudad: json['ciudad'] as String,
      );
}

class HorarioRango {
  final String ini;
  final String fin;

  const HorarioRango({required this.ini, required this.fin});

  factory HorarioRango.fromJson(Map<String, dynamic> json) =>
      HorarioRango(ini: json['horaIni'] as String, fin: json['horaFin'] as String);
}
