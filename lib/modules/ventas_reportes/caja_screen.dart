import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/catalog_repository.dart';
import '../../core/offline_sync.dart';
import '../../core/session.dart';

/// Estimate only: server recalculates promotions and rejects stale snapshots.
/// Integer cents reproduce per-unit HALF_UP rounding without binary floats.
Map<String,dynamic> cashIntent(List<Map<String,dynamic>> lines) {
  int cents(dynamic value) {
    final text=value.toString();final parts=text.split('.');
    return int.parse(parts[0])*100+int.parse('${parts.length>1?parts[1]:''}00'.substring(0,2));
  }
  var discount=0;var hasPromotion=false;
  for(final line in lines){
    final promo=line['promotion'] as Map?;if(promo==null)continue;hasPromotion=true;
    final base=cents(line['price']);final value=cents(promo['valorDescuento']);
    final unit=(promo['tipoDescuento']=='porcentaje'?(base*value+5000)~/10000:value).clamp(0,base).toInt();
    discount+=unit*(line['quantity'] as int);
  }
  return {'metodo':'efectivo','lineas':lines.map((line)=>{'idVariante':line['id'],'cantidad':line['quantity'],'precio':line['price']}).toList(),
    if(hasPromotion)'descuento':'${discount~/100}.${(discount%100).toString().padLeft(2,'0')}'};
}

/// Minimal cashier-only cash intents. No client checkout, electronic approval,
/// or local success is represented as a server-confirmed sale.
class CajaScreen extends StatelessWidget {
  final ApiClient? api;
  final CatalogRepository? repository;
  const CajaScreen({super.key, this.api, this.repository});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    if (!session.isAuthenticated || session.user?.isCashier != true) {
      return const Scaffold(body: Center(child: Text('Acceso reservado a cajeros con permiso CU24.')));
    }
    return _CashView(key: ValueKey((session.user, session.status)),api:api,repository:repository);
  }
}

class _CashView extends StatefulWidget {
  final ApiClient? api;
  final CatalogRepository? repository;
  const _CashView({super.key,this.api,this.repository});
  @override
  State<_CashView> createState() => _CashViewState();
}

class _CashViewState extends State<_CashView> {
  late final _api = widget.api ?? ApiClient();
  late final _repository = widget.repository ?? CatalogRepository();
  List<Map<String,dynamic>> _variants = [];
  List<Map<String,dynamic>> _branches = [];
  List<Map<String,dynamic>> _lines = [];
  List<OfflineOperation> _operations = [];
  String? _selected, _message, _error;
  int? _branch;
  int _quantity = 1;
  bool _busy = false;
  DateTime? _downloaded;
  String? _intent;
  @override
  void initState(){ super.initState(); _load(); }
  @override
  void dispose(){if(widget.api==null)_api.close();super.dispose();}
  Future<void> _load() async {
    try {
      final session=context.read<SessionState>();final owner=session.user!;
      final saved=await _repository.read(owner.empresa!,owner.idUsuario,'cash:page');
      final operations=await session.sync.list();if(!mounted)return;
      setState((){_variants=(saved?.data['variants'] as List? ?? []).cast<Map<String,dynamic>>();
        _branches=(saved?.data['branches'] as List? ?? []).cast<Map<String,dynamic>>();
        _branch=_branches.isEmpty?null:(_branches.first['nro'] as num).toInt();_downloaded=saved?.downloadedAt;
        _operations=operations.where((operation)=>operation.type=='venta').toList();});
    } catch(_){if(mounted)setState(()=>_error='No se pudo leer SQLite. Conserva los datos y reintenta.');}
  }
  Future<void> _download() async {
    if(_busy)return;setState((){_busy=true;_error=null;});
    final session=context.read<SessionState>();final owner=session.user!;final credential=session.credentialForApi;
    try {
      final refs=jsonDecode((await _api.getRaw('/api/admin/caja/referencias',credential:credential)).body) as Map<String,dynamic>;
      final page=jsonDecode((await _api.getRaw('/api/admin/caja/productos?limit=20',credential:credential)).body) as Map<String,dynamic>;
      final details=<Map<String,dynamic>>[];final variants=<Map<String,dynamic>>[];
      for(final product in page['items'] as List){
        final detail=jsonDecode((await _api.getRaw('/api/admin/caja/productos/${Uri.encodeComponent(product['idProd'] as String)}',credential:credential)).body) as Map<String,dynamic>;
        details.add(detail);
        for(final variant in detail['variantes'] as List){variants.add({'id':variant['idVariante'],'label':'${detail['descripcion']} · ${variant['talla']['descripcion']}',
          'price':variant['precio'],'promotion':detail['promocion'],'availability':detail['disponibilidad']});}
      }
      if(!mounted || session.user!=owner)return;
      await _repository.saveSubset(tenant:owner.empresa!,user:owner.idUsuario,pageKey:'cash:page',
        page:{'branches':refs['sucursales'],'variants':variants},details:details,facets:{});
      if(!mounted)return;await _load();if(mounted)setState(()=>_message='Subconjunto de caja guardado en SQLite. Existencias y precios pueden cambiar.');
    } catch(_){if(mounted)setState(()=>_error='No se pudo descargar. Conéctate con una sesión de cajero vigente; la copia anterior se conserva.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _save() async {
    if(_busy||_lines.isEmpty||_branch==null||_intent!=null)return;
    setState((){_busy=true;_error=null;});
    final session=context.read<SessionState>();
    try {
      final id=await session.sync.enqueue(type:'venta',branch:_branch!,data:cashIntent(_lines));
      if(!mounted)return;setState((){_intent=id;_message='Venta local pendiente $id. No es un pago electrónico ni garantiza aceptación del servidor.';});
      await session.sync.flush();if(mounted)await _load();
    } catch(_){if(mounted)setState(()=>_error='No se pudo completar. Revisa la cola antes de crear otra venta; no borres operaciones pendientes.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _sync() async {await context.read<SessionState>().sync.flush();if(mounted)await _load();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Caja · contado offline'),actions:[IconButton(onPressed:()=>context.read<SessionState>().logout(),icon:const Icon(Icons.logout),tooltip:'Cerrar sesión')]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Solo efectivo. Una venta guardada localmente aún no reduce stock del servidor ni es una venta confirmada.'),
      Text(_downloaded==null?'Descarga un subconjunto autorizado antes de trabajar offline.':'Datos conocidos: $_downloaded. Pueden estar desactualizados.'),
      TextButton(onPressed:_busy?null:_download,child:const Text('Descargar 20 productos para caja')),
      if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),if(_message!=null)Text(_message!),
      DropdownButtonFormField<int>(initialValue:_branch,decoration:const InputDecoration(labelText:'Sucursal autorizada'),items:_branches.map((branch)=>DropdownMenuItem(value:(branch['nro'] as num).toInt(),child:Text(branch['nombre'] as String))).toList(),onChanged:_intent!=null?null:(value)=>setState(()=>_branch=value)),
      DropdownButtonFormField<String>(initialValue:_selected,decoration:const InputDecoration(labelText:'Prenda descargada'),items:_variants.map((variant)=>DropdownMenuItem(value:variant['id'] as String,child:Text('${variant['label']} · ${variant['price']}'))).toList(),onChanged:(value)=>setState(()=>_selected=value)),
      TextFormField(initialValue:'1',decoration:const InputDecoration(labelText:'Cantidad'),keyboardType:TextInputType.number,onChanged:(value)=>_quantity=int.tryParse(value)??0),
      TextButton(onPressed:_intent!=null||_selected==null||_busy?null:(){if(_quantity<1||_quantity>100){setState(()=>_error='Cantidad entera entre 1 y 100.');return;}
        final variant=_variants.firstWhere((v)=>v['id']==_selected);
        final index=_lines.indexWhere((line)=>line['id']==_selected);
        final total=_quantity+(index<0?0:_lines[index]['quantity'] as int);
        if(total>100 || (index<0 && _lines.length>=50)){setState(()=>_error='El lote admite hasta 50 variantes y 100 unidades por variante.');return;}
        setState(()=>_lines=[..._lines.where((line)=>line['id']!=_selected),{...variant,'quantity':total}]);},child:const Text('Añadir línea')),
      for(final line in _lines)Text('${line['label']} × ${line['quantity']}'),
      FilledButton(onPressed:_busy||_lines.isEmpty||_intent!=null?null:_save,child:const Text('Guardar venta de efectivo pendiente')),
      if(_intent!=null)TextButton(onPressed:()=>setState((){_lines=[];_intent=null;_message=null;}),child:const Text('Nueva venta distinta')),
      TextButton(onPressed:_busy?null:_sync,child:const Text('Sincronizar y consultar resultados')),
      const Text('Ledger de ventas del dispositivo'),
      for(final operation in _operations)ListTile(title:Text('${operation.state.name} · ${operation.id}'),subtitle:Text('${operation.code??''} ${operation.detail??''}'),trailing:operation.nroVenta==null?null:Text('Venta ${operation.nroVenta}')),
    ]));
}
