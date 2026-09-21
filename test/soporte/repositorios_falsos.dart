import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu01_registro_cliente/data/registro_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu02_iniciar_sesion/data/sesion_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu04_recuperar_contrasena/data/recuperacion_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/data/catalogo_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu10_consultar_prendas/models/producto.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/data/reservas_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu11_gestionar_reserva/models/reserva.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/data/carrito_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu12_carrito/models/carrito.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/data/compra_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu13_compra_digital/models/compra.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/data/pago_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu14_pago_electronico/models/pago.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu15_historial_compra/data/historial_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu15_historial_compra/models/compra_historial.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu17_recomendaciones/data/recomendaciones_repository.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/cu17_recomendaciones/models/recomendacion.dart';
import 'package:liveclothesshop_mobile/modules/cliente_experiencia_compra/shared/models/sesion.dart';

import 'datos_falsos.dart';

/// Repositorios falsos: las pantallas y providers se prueban sin backend real.

class SesionRepositoryFalso implements SesionRepository {
  SesionRepositoryFalso({this.sesion, this.error});

  /// Sesión devuelta por `sesionActual` (null = sin sesión activa).
  Sesion? sesion;
  Object? error;
  int logins = 0;
  int logouts = 0;

  @override
  Future<Sesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    logins += 1;
    if (error != null) throw error!;
    return sesion = sesionFalsa();
  }

  @override
  Future<Sesion?> sesionActual() async => error != null ? throw error! : sesion;

  @override
  Future<void> cerrarSesion() async {
    logouts += 1;
    sesion = null;
  }
}

class CatalogoRepositoryFalso implements CatalogoRepository {
  CatalogoRepositoryFalso({this.error, this.total = 1});

  Object? error;
  int total;
  int llamadas = 0;

  @override
  Future<ProductosCatalogo> listar(FiltrosCatalogo filtros) async {
    llamadas += 1;
    if (error != null) throw error!;
    return ProductosCatalogo(
      items: [productoFalso()],
      total: total,
      offset: 0,
      limit: 20,
    );
  }

  @override
  Future<ProductoDetalle> detalle(String idProd) async {
    if (error != null) throw error!;
    return detalleFalso(id: idProd);
  }

  @override
  Future<List<FacetaItem>> faceta(String grupo) async => const [];

  @override
  Future<FacetasCatalogo> facetas() async => const FacetasCatalogo();
}

class CarritoRepositoryFalso implements CarritoRepository {
  CarritoRepositoryFalso({this.vacio = false, this.error});

  bool vacio;
  Object? error;
  int cambios = 0;
  int eliminados = 0;

  @override
  Future<Carrito> obtener() async =>
      error != null ? throw error! : carritoFalso(vacio: vacio);

  @override
  Future<Carrito> agregar({
    required String idVar,
    required int cantidad,
  }) async {
    if (error != null) throw error!;
    return carritoFalso();
  }

  @override
  Future<Carrito> cambiarCantidad({
    required int idDetalleCarro,
    required int cantidad,
  }) async {
    cambios += 1;
    if (error != null) throw error!;
    return carritoFalso();
  }

  @override
  Future<Carrito> eliminar(int idDetalleCarro) async {
    eliminados += 1;
    if (error != null) throw error!;
    return carritoFalso(vacio: true);
  }
}

class ReservasRepositoryFalso implements ReservasRepository {
  ReservasRepositoryFalso({
    this.estado = 'confirmada',
    this.error,
    this.sinReservas = false,
  });

  String estado;
  Object? error;
  bool sinReservas;
  int canceladas = 0;

  @override
  Future<ReservasListado> listar({
    int offset = 0,
    int limit = 20,
    String? estado,
  }) async {
    if (error != null) throw error!;
    return ReservasListado(
      items: sinReservas ? const [] : [reservaFalsa(estado: this.estado)],
      total: sinReservas ? 0 : 1,
    );
  }

  @override
  Future<Reserva> detalle(int nroReserva) async =>
      error != null ? throw error! : reservaFalsa(estado: estado);

  @override
  Future<Reserva> crear({
    required int nroSuc,
    required String fechaReserva,
    required String horaAtencion,
    required List<Map<String, Object>> items,
  }) async => error != null ? throw error! : reservaFalsa(estado: 'pendiente');

  @override
  Future<Reserva> cancelar(int nroReserva) async {
    canceladas += 1;
    if (error != null) throw error!;
    estado = 'cancelada';
    return reservaFalsa(estado: 'cancelada');
  }

  @override
  Future<List<SucursalCliente>> sucursales() async => const [
    SucursalCliente(
      nro: 1,
      nombre: 'Central',
      direccion: 'Dir 1',
      ciudad: 'La Paz',
    ),
  ];

  @override
  Future<HorariosSucursal> horarios(int nroSuc) async => const HorariosSucursal(
    nroSuc: 1,
    rangos: [HorarioRango(horaIni: '09:00:00', horaFin: '12:00:00')],
  );
}

class CompraRepositoryFalso implements CompraRepository {
  CompraRepositoryFalso({this.pendienteVenta, this.error});

  VentaDetalle? pendienteVenta;
  Object? error;
  int preparadas = 0;

  @override
  Future<VentaDetalle> checkout({required int nroSuc, String? nit}) async {
    preparadas += 1;
    if (error != null) throw error!;
    return pendienteVenta = ventaFalsa();
  }

  @override
  Future<VentaDetalle?> pendiente() async =>
      error != null ? throw error! : pendienteVenta;

  @override
  Future<VentaDetalle> detalle(int nroVenta) async =>
      error != null ? throw error! : ventaFalsa();

  @override
  Future<VentaDetalle> cancelar(int nroVenta) async {
    if (error != null) throw error!;
    pendienteVenta = null;
    return ventaFalsa(estado: 'anulada');
  }
}

class PagoRepositoryFalso implements PagoRepository {
  PagoRepositoryFalso({
    this.simulacion = false,
    this.checkoutUrl,
    this.estadoFinal = 'pendiente',
    this.error,
  });

  bool simulacion;
  String? checkoutUrl;
  String estadoFinal;
  Object? error;
  int iniciados = 0;
  int reconciliados = 0;

  @override
  Future<ConfiguracionPago> configuracion() async => ConfiguracionPago(
    proveedor: simulacion ? 'mock' : 'stripe',
    simulacion: simulacion,
    disponible: true,
    moneda: 'usd',
  );

  @override
  Future<PagoDetalle> iniciar({
    required int nroVenta,
    required String metodo,
  }) async {
    iniciados += 1;
    if (error != null) throw error!;
    return pagoFalso(checkoutUrl: checkoutUrl);
  }

  @override
  Future<PagoDetalle> detalle(int idPago) async =>
      error != null ? throw error! : pagoFalso(estado: estadoFinal);

  @override
  Future<PagoDetalle> reconciliar(int idPago) async {
    reconciliados += 1;
    if (error != null) throw error!;
    return pagoFalso(estado: estadoFinal, checkoutUrl: checkoutUrl);
  }

  @override
  Future<PagoDetalle> procesar(int idPago, {String? escenario}) async =>
      error != null ? throw error! : pagoFalso(estado: estadoFinal);
}

class HistorialRepositoryFalso implements HistorialRepository {
  HistorialRepositoryFalso({this.sinCompras = false, this.error});

  bool sinCompras;
  Object? error;

  @override
  Future<HistorialCompras> listar({int offset = 0, int limit = 20}) async {
    if (error != null) throw error!;
    if (sinCompras) {
      return HistorialCompras(
        total: 0,
        mensaje: 'No existen compras en tu historial',
      );
    }
    return HistorialCompras.fromJson(historialJson().cast<String, dynamic>());
  }

  @override
  Future<CompraDetalle> detalle(int nroVenta) async =>
      error != null ? throw error! : compraHistorialFalsa();
}

class RecomendacionesRepositoryFalso implements RecomendacionesRepository {
  RecomendacionesRepositoryFalso({
    this.tipo = 'personalizada',
    this.sinItems = false,
    this.error,
  });

  String tipo;
  bool sinItems;
  Object? error;
  int llamadas = 0;

  @override
  Future<RecomendacionesRespuesta> listar({int limit = 8}) async {
    llamadas += 1;
    if (error != null) throw error!;
    return RecomendacionesRespuesta.fromJson(
      recomendacionesJson(
        tipo: tipo,
        items: sinItems ? const [] : null,
      ).cast<String, dynamic>(),
    );
  }
}

class RegistroRepositoryFalso implements RegistroRepository {
  RegistroRepositoryFalso({this.error});

  Object? error;
  Map<String, dynamic>? enviado;

  @override
  Future<({Sesion sesion, String mensaje})> registrar(
    Map<String, dynamic> datos,
  ) async {
    enviado = datos;
    if (error != null) throw error!;
    return (sesion: sesionFalsa(), mensaje: 'Cliente registrado correctamente');
  }
}

class RecuperacionRepositoryFalso implements RecuperacionRepository {
  RecuperacionRepositoryFalso({this.error});

  Object? error;
  int solicitudes = 0;
  String? token;

  @override
  Future<void> solicitar(String correo) async {
    solicitudes += 1;
    if (error != null) throw error!;
  }

  @override
  Future<void> restablecer({
    required String token,
    required String nuevaContrasena,
  }) async {
    this.token = token;
    if (error != null) throw error!;
  }
}
