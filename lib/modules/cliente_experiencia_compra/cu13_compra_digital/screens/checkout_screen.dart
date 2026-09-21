import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../cu11_gestionar_reserva/providers/reservas_provider.dart';
import '../../cu12_carrito/models/carrito.dart';
import '../../cu12_carrito/providers/carrito_provider.dart';
import '../models/compra.dart';
import '../providers/compra_provider.dart';

/// CU13 Compra digital: resumen del carrito y registro de la venta.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  static const String routePath = '/checkout';

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _nit = TextEditingController();
  int? _nroSuc;
  bool _enviando = false;
  String? _aviso;

  @override
  void dispose() {
    _nit.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_nroSuc == null) {
      setState(() => _aviso = 'Selecciona la sucursal de retiro.');
      return;
    }
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      final venta = await ref
          .read(checkoutProvider.notifier)
          .preparar(nroSuc: _nroSuc!, nit: _nit.text);
      if (mounted) context.go('/pago?nroVenta=${venta.nroVenta}');
    } on AppException catch (error) {
      setState(() => _aviso = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);
    final pendiente = ref.watch(checkoutProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de compra')),
      body: carrito.when(
        loading: () => const LoadingView(message: 'Preparando tu compra…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () => ref.read(carritoProvider.notifier).refrescar(),
          ),
        ),
        data: (carga) => _contenido(carga, pendiente),
      ),
    );
  }

  Widget _contenido(Carrito carga, VentaDetalle? ventaPendiente) {
    if (carga.vacio && ventaPendiente == null) {
      return EmptyView(
        icon: Icons.shopping_bag_outlined,
        title: 'No hay productos por comprar',
        message: 'Agrega poleras al carrito antes de continuar.',
        actionLabel: 'Ver catálogo',
        onAction: () => context.go('/catalogo'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppTheme.gapLarge),
      children: [
        if (_aviso != null) ...[
          NoticeBanner(message: _aviso!),
          const SizedBox(height: AppTheme.gap),
        ],
        if (ventaPendiente != null) ...[
          _resumenBackend(ventaPendiente),
          const SizedBox(height: AppTheme.gap),
          ElevatedButton(
            onPressed: () =>
                context.go('/pago?nroVenta=${ventaPendiente.nroVenta}'),
            child: const Text('Continuar con el pago pendiente'),
          ),
          const SizedBox(height: AppTheme.gap),
          OutlinedButton(
            onPressed: () => context.go('/compra/${ventaPendiente.nroVenta}'),
            child: const Text('Ver detalle de la compra'),
          ),
        ] else ...[
          Text('Productos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in carga.items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.producto),
              subtitle: Text(
                'Talla ${item.talla.descripcion} · ${item.cantidad} unidad(es)',
              ),
              trailing: Text(money(item.subtotal)),
            ),
          const Divider(),
          Row(
            children: [
              const Text('Subtotal del carrito'),
              const Spacer(),
              Text(
                money(carga.subtotal),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.gapLarge),
          _selectorSucursal(),
          const SizedBox(height: AppTheme.gap),
          TextField(
            controller: _nit,
            decoration: const InputDecoration(
              labelText: 'NIT para la factura (opcional)',
            ),
          ),
          const SizedBox(height: AppTheme.gap),
          const Text(
            'El descuento y el total definitivo los calcula el backend al confirmar la compra.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: AppTheme.gap),
          ElevatedButton(
            onPressed: _enviando ? null : _confirmar,
            child: Text(_enviando ? 'Registrando…' : 'Confirmar compra'),
          ),
        ],
      ],
    );
  }

  Widget _selectorSucursal() {
    final sucursales = ref.watch(sucursalesProvider);
    return sucursales.when(
      loading: () => const LoadingView(message: 'Cargando sucursales…'),
      error: (error, _) => ErrorView(
        message: mensajeDeError(error),
        onRetry: () => ref.invalidate(sucursalesProvider),
      ),
      data: (lista) => DropdownButtonFormField<int>(
        initialValue: _nroSuc,
        decoration: const InputDecoration(labelText: 'Sucursal de retiro'),
        items: [
          for (final sucursal in lista)
            DropdownMenuItem(
              value: sucursal.nro,
              child: Text('${sucursal.nombre} · ${sucursal.ciudad}'),
            ),
        ],
        onChanged: (value) => setState(() => _nroSuc = value),
      ),
    );
  }

  Widget _resumenBackend(VentaDetalle venta) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compra #${venta.nroVenta} pendiente de pago',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Sucursal: ${venta.sucursal.nombre} · ${venta.sucursal.ciudad}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            _importe('Bruto', venta.brutoTotal),
            _importe('Descuento aplicado', -venta.descAplicado),
            _importe('Total', venta.total, destacado: true),
          ],
        ),
      ),
    );
  }

  Widget _importe(String etiqueta, double valor, {bool destacado = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(
              etiqueta,
              style: TextStyle(fontWeight: destacado ? FontWeight.w600 : null),
            ),
            const Spacer(),
            Text(
              money(valor),
              style: TextStyle(fontWeight: destacado ? FontWeight.w700 : null),
            ),
          ],
        ),
      );
}
