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
import '../../cu13_compra_digital/models/compra.dart';
import '../../cu13_compra_digital/providers/compra_provider.dart';
import '../data/checkout_launcher.dart';
import '../models/pago.dart';
import '../providers/pago_provider.dart';

/// CU14 Pago electrónico con Stripe Checkout.
///
/// La app NO captura tarjeta (PAN/CVC/expiración): abre la página segura de
/// Stripe con url_launcher y, al volver, consulta el estado real al backend.
class PagoScreen extends ConsumerStatefulWidget {
  const PagoScreen({super.key, required this.nroVenta});

  static const String routePath = '/pago';

  final int nroVenta;

  @override
  ConsumerState<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends ConsumerState<PagoScreen>
    with WidgetsBindingObserver {
  String _metodo = 'tarjeta';
  bool _ocupado = false;
  String? _aviso;
  bool _exito = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del navegador de Stripe se consulta el estado real del pago.
    if (state == AppLifecycleState.resumed &&
        (ref.read(pagoProvider)?.pendiente ?? false)) {
      _reconciliar(silencioso: true);
    }
  }

  Future<void> _ejecutar(
    Future<PagoDetalle> Function() accion, {
    bool silencioso = false,
  }) async {
    if (!silencioso) setState(() => _ocupado = true);
    try {
      final pago = await accion();
      if (!mounted) return;
      setState(() {
        _exito = pago.aprobado;
        _aviso = switch (pago.estado) {
          'aprobado' => 'Pago aprobado. ¡Gracias por tu compra!',
          'rechazado' =>
            'El pago fue rechazado. Puedes intentarlo con otro método.',
          _ => 'El pago sigue pendiente. Si ya pagaste, verifica el estado.',
        };
      });
      if (pago.aprobado) ref.invalidate(ventaDetalleProvider(widget.nroVenta));
    } on AppException catch (error) {
      if (mounted) setState(() => _aviso = error.message);
    } finally {
      if (mounted && !silencioso) setState(() => _ocupado = false);
    }
  }

  Future<void> _pagar() async {
    final simulacion =
        ref.read(configuracionPagoProvider).asData?.value.simulacion ?? false;
    setState(() {
      _ocupado = true;
      _aviso = null;
      _exito = false;
    });
    try {
      final pago = await ref
          .read(pagoProvider.notifier)
          .iniciar(nroVenta: widget.nroVenta, metodo: _metodo);
      if ((pago.checkoutUrl ?? '').isNotEmpty) {
        final abierto = await ref
            .read(checkoutLauncherProvider)
            .abrir(pago.checkoutUrl);
        if (mounted && !abierto) {
          setState(
            () => _aviso = 'No pudimos abrir la página de pago de Stripe.',
          );
        }
      } else if (simulacion) {
        // Pasarela de simulación (desarrollo): el cobro lo resuelve el backend.
        await _ejecutar(
          () => ref.read(pagoProvider.notifier).procesar(escenario: 'aprobado'),
        );
      }
    } on AppException catch (error) {
      setState(() => _aviso = error.message);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _reconciliar({bool silencioso = false}) => _ejecutar(
    () => ref.read(pagoProvider.notifier).reconciliar(),
    silencioso: silencioso,
  );

  @override
  Widget build(BuildContext context) {
    final venta = ref.watch(ventaDetalleProvider(widget.nroVenta));
    final config = ref.watch(configuracionPagoProvider);
    final pago = ref.watch(pagoProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Pago de la compra #${widget.nroVenta}')),
      body: venta.when(
        loading: () => const LoadingView(message: 'Cargando la compra…'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapLarge),
          child: ErrorView(
            message: mensajeDeError(error),
            onRetry: () =>
                ref.invalidate(ventaDetalleProvider(widget.nroVenta)),
          ),
        ),
        data: (detalle) => detalle.items.isEmpty
            ? const EmptyView(
                title: 'Compra sin productos',
                message: 'No hay nada que pagar en esta compra.',
              )
            : _contenido(detalle, config, pago),
      ),
    );
  }

  Widget _contenido(
    VentaDetalle detalle,
    AsyncValue<ConfiguracionPago> config,
    PagoDetalle? pago,
  ) {
    final stripe = config.asData?.value.proveedor == 'stripe';
    return ListView(
      padding: const EdgeInsets.all(AppTheme.gapLarge),
      children: [
        if (_aviso != null) ...[
          NoticeBanner(message: _aviso!, success: _exito),
          const SizedBox(height: AppTheme.gap),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total a pagar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  money(detalle.total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sucursal ${detalle.sucursal.nombre} · ${detalle.sucursal.ciudad}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.gapLarge),
        Text('Método de pago', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metodo in const {
              'tarjeta': 'Tarjeta (Stripe)',
              'QR': 'QR',
              'transferencia': 'Transferencia',
            }.entries)
              ChoiceChip(
                label: Text(metodo.value),
                selected: _metodo == metodo.key,
                onSelected: (_) => setState(() => _metodo = metodo.key),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.gap),
        if (pago != null) ...[
          NoticeBanner(
            message: 'Estado del pago: ${etiquetaPago(pago.estado)}',
            success: pago.aprobado,
          ),
          const SizedBox(height: AppTheme.gap),
        ],
        if (!_exito)
          ElevatedButton(
            onPressed: _ocupado ? null : _pagar,
            child: Text(
              _ocupado
                  ? 'Procesando…'
                  : (stripe ? 'Pagar con Stripe' : 'Pagar'),
            ),
          ),
        if (pago != null && !pago.aprobado) ...[
          const SizedBox(height: AppTheme.gap),
          OutlinedButton(
            onPressed: _ocupado ? null : () => _reconciliar(),
            child: const Text('Ya pagué: verificar estado'),
          ),
        ],
        if (pago?.aprobado ?? false) ...[
          const SizedBox(height: AppTheme.gap),
          OutlinedButton(
            onPressed: () => context.go('/historial'),
            child: const Text('Ver mis compras'),
          ),
        ],
        const SizedBox(height: AppTheme.gapLarge),
        const Text(
          'La aplicación no solicita ni almacena números de tarjeta, códigos de '
          'seguridad ni fechas de expiración: Stripe Checkout los gestiona.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}
