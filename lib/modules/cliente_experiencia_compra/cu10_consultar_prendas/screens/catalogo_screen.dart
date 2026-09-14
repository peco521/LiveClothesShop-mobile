import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api_error.dart';
import '../../../../core/session.dart';
import '../data/catalogo_api.dart';
import '../models/catalogo.dart';
import 'detalle_screen.dart';

/// Catálogo de prendas: búsqueda, filtros, grilla adaptable y paginación.
class CatalogoScreen extends StatefulWidget {
  final CatalogoApi? api;

  const CatalogoScreen({super.key, this.api});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _busqueda = TextEditingController();
  CatalogoFiltros _filtros = const CatalogoFiltros();
  final List<ProductoResumen> _items = [];
  int _total = 0;
  int _offset = 0;
  static const _limit = 20;
  bool _busy = false;
  bool _moreBusy = false;
  String? _error;
  Map<String, List<FacetaItem>> _facetas = {};

  CatalogoApi get _api {
    final api = widget.api;
    if (api != null) return api;
    final session = context.read<SessionState>();
    return CatalogoApi(credential: () => session.credentialForApi);
  }

  @override
  void initState() {
    super.initState();
    _cargarFacetas();
    _cargar(reset: true);
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarFacetas() async {
    try {
      const grupos = ['categorias', 'marcas', 'colecciones', 'temporadas', 'tallas', 'colores'];
      final entries = <String, List<FacetaItem>>{};
      for (final grupo in grupos) {
        entries[grupo] = await _api.faceta(grupo);
      }
      if (mounted) setState(() => _facetas = entries);
    } catch (_) {
      // Las facetas son opcionales: el catálogo funciona sin ellas.
    }
  }

  Future<void> _cargar({bool reset = false}) async {
    if (_busy || _moreBusy) return;
    setState(() {
      if (reset) {
        _busy = true;
        _error = null;
      } else {
        _moreBusy = true;
      }
    });
    try {
      final page = await _api.listar(_filtros, offset: reset ? 0 : _offset, limit: _limit);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items.clear();
        }
        _items.addAll(page.items);
        _total = page.total;
        _offset = (reset ? 0 : _offset) + page.items.length;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _moreBusy = false;
        });
      }
    }
  }

  void _buscar() {
    setState(() => _filtros = CatalogoFiltros(
      q: _busqueda.text,
      categoria: _filtros.categoria,
      marca: _filtros.marca,
      coleccion: _filtros.coleccion,
      temporada: _filtros.temporada,
      talla: _filtros.talla,
      color: _filtros.color,
      minPrecio: _filtros.minPrecio,
      maxPrecio: _filtros.maxPrecio,
      soloDisponibles: _filtros.soloDisponibles,
      sort: _filtros.sort,
    ));
    _cargar(reset: true);
  }

  Future<void> _abrirFiltros() async {
    final resultado = await showModalBottomSheet<CatalogoFiltros>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FiltrosSheet(filtros: _filtros, facetas: _facetas),
    );
    if (resultado != null && mounted) {
      setState(() => _filtros = resultado);
      _cargar(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Carrito',
            onPressed: () => Navigator.of(context).pushNamed('/tienda/carrito'),
          ),
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Mis reservas',
            onPressed: () => Navigator.of(context).pushNamed('/tienda/reservas'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await session.logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _busqueda,
                    decoration: const InputDecoration(
                      labelText: 'Buscar prendas',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filtros',
                  onPressed: _abrirFiltros,
                ),
              ],
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: () => _cargar(reset: true), child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No hay prendas para los filtros aplicados.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft, child: Text('$_total prendas encontradas.')),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) => _tarjeta(_items[i]),
          ),
        ),
        if (_items.length < _total)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonal(
              onPressed: _moreBusy ? null : () => _cargar(),
              child: Text(_moreBusy ? 'Cargando…' : 'Cargar más'),
            ),
          ),
      ],
    );
  }

  Widget _tarjeta(ProductoResumen item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetalleScreen(idProd: item.idProd, api: widget.api)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: item.imagen != null
                  ? Image.network(item.imagen!, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 48))
                  : const Center(child: Icon(Icons.checkroom, size: 48)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${item.marca} · ${item.categoria}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(item.precioTexto),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(item.disponible ? 'Disponible' : 'Agotado'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja inferior de filtros con las facetas del backend.
class _FiltrosSheet extends StatefulWidget {
  final CatalogoFiltros filtros;
  final Map<String, List<FacetaItem>> facetas;

  const _FiltrosSheet({required this.filtros, required this.facetas});

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  late int? categoria = widget.filtros.categoria;
  late int? marca = widget.filtros.marca;
  late int? coleccion = widget.filtros.coleccion;
  late int? temporada = widget.filtros.temporada;
  late int? talla = widget.filtros.talla;
  late int? color = widget.filtros.color;
  late bool disponibles = widget.filtros.soloDisponibles;
  late String orden = widget.filtros.sort;
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.filtros.minPrecio != null) _min.text = '${widget.filtros.minPrecio}';
    if (widget.filtros.maxPrecio != null) _max.text = '${widget.filtros.maxPrecio}';
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Widget _combo(String etiqueta, String clave, int? valor, ValueChanged<int?> cambio) {
    final opciones = widget.facetas[clave] ?? const [];
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(labelText: etiqueta),
      initialValue: valor,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('Todas')),
        ...opciones.map((e) => DropdownMenuItem<int>(value: e.id, child: Text(e.nombre))),
      ],
      onChanged: cambio,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _combo('Categoría', 'categorias', categoria, (v) => setState(() => categoria = v)),
            _combo('Marca', 'marcas', marca, (v) => setState(() => marca = v)),
            _combo('Colección', 'colecciones', coleccion, (v) => setState(() => coleccion = v)),
            _combo('Temporada', 'temporadas', temporada, (v) => setState(() => temporada = v)),
            _combo('Talla', 'tallas', talla, (v) => setState(() => talla = v)),
            _combo('Color', 'colores', color, (v) => setState(() => color = v)),
            Row(
              children: [
                Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio mínimo'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio máximo'))),
              ],
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Orden'),
              initialValue: orden,
              items: const [
                DropdownMenuItem(value: 'nombre_asc', child: Text('Nombre A–Z')),
                DropdownMenuItem(value: 'nombre_desc', child: Text('Nombre Z–A')),
                DropdownMenuItem(value: 'precio_asc', child: Text('Menor precio')),
                DropdownMenuItem(value: 'precio_desc', child: Text('Mayor precio')),
              ],
              onChanged: (v) => setState(() => orden = v ?? 'nombre_asc'),
            ),
            SwitchListTile(
              title: const Text('Solo disponibles'),
              value: disponibles,
              onChanged: (v) => setState(() => disponibles = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const CatalogoFiltros()),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(CatalogoFiltros(
                      categoria: categoria, marca: marca, coleccion: coleccion, temporada: temporada,
                      talla: talla, color: color, minPrecio: double.tryParse(_min.text),
                      maxPrecio: double.tryParse(_max.text), soloDisponibles: disponibles, sort: orden,
                    )),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
