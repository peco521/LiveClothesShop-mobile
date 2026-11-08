import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/api_error.dart';
import '../../../core/session.dart';

class HistorialScreen extends StatelessWidget {
  final ApiClient? api;
  const HistorialScreen({super.key,this.api});
  @override
  Widget build(BuildContext context){
    final session=context.watch<SessionState>();
    if(!session.isAuthenticated || session.user?.tipo!='C') {
      return Scaffold(appBar:AppBar(title:const Text('Historial de compras')),
        body:const Center(child:Text('Inicia sesión como cliente para consultar tus compras.')));
    }
    return _HistoryView(key:ValueKey((session.user,session.status)),api:api);
  }
}
class _HistoryView extends StatefulWidget {
  final ApiClient? api;
  const _HistoryView({super.key,this.api});
  @override State<_HistoryView> createState()=>_HistoryViewState();
}
class _HistoryViewState extends State<_HistoryView> {
  late final _api=widget.api??ApiClient();
  List<Map<String,dynamic>> _items=[];
  Map<String,dynamic>? _detail;
  bool _busy=false;
  String? _error;
  int _offset=0,_total=0;
  @override void initState(){super.initState();_load(0);}
  @override void dispose(){if(widget.api==null)_api.close();super.dispose();}
  Future<void> _load(int offset) async{
    final session=context.read<SessionState>();final owner=session.user;
    setState((){_busy=true;_error=null;_detail=null;});
    try{
      final response=await _api.getRaw('/api/cliente/historial-compras?offset=$offset&limit=20',credential:session.credentialForApi);
      final data=jsonDecode(response.body) as Map<String,dynamic>;
      if(!mounted||owner!=session.user)return;
      setState((){_items=(data['items'] as List).cast<Map<String,dynamic>>();_total=(data['total'] as num).toInt();_offset=offset;});
    }on ApiException catch(error){
      if(mounted&&owner==session.user){
        if(error.status==401){await session.logout();}
        else{setState(()=>_error=error.userMessage);}
      }
    }
    catch(_){if(mounted&&owner==session.user)setState(()=>_error='No se pudo consultar el historial. Necesitas conexión.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _open(int sale) async{
    final session=context.read<SessionState>();final owner=session.user;
    setState((){_busy=true;_error=null;});
    try{
      final response=await _api.getRaw('/api/cliente/historial-compras/$sale',credential:session.credentialForApi);
      if(!mounted||owner!=session.user)return;
      setState(()=>_detail=jsonDecode(response.body) as Map<String,dynamic>);
    }on ApiException catch(error){
      if(mounted&&owner==session.user){
        if(error.status==401){await session.logout();}
        else{setState(()=>_error=error.userMessage);}
      }
    }
    catch(_){if(mounted&&owner==session.user)setState(()=>_error='No se pudo consultar la compra.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Historial de compras')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Importes históricos del servidor. Los precios actuales del catálogo no sustituyen el importe pagado.'),
      if(_busy)const LinearProgressIndicator(),if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
      if(_detail case final detail?)...[
        Text('Compra ${detail['nroVenta']}',style:Theme.of(context).textTheme.titleLarge),
        Text('${detail['estado']} · pago ${detail['estadoPago']??'sin pago'}'),
        Text('Total: ${detail['total']} · Descuento: ${detail['descAplicado']}'),
        for(final item in detail['items'] as List)ListTile(title:Text(item['producto'] as String),subtitle:Text('${item['cantidad']} × ${item['precioUnitario']}')),
        if(detail['pago'] case final Map payment)Text('Proveedor / referencia: ${payment['referencia']??'Sin referencia'}'),
        TextButton(onPressed:()=>setState(()=>_detail=null),child:const Text('Volver al historial')),
      ]else...[
        Text('$_total compras'),if(!_busy&&_items.isEmpty)const Text('No existen compras en tu historial'),
        for(final item in _items)ListTile(title:Text('Compra ${item['nroVenta']} · ${item['monto']}'),
          subtitle:Text('${item['fechaHora']} · ${item['estadoPago']??'sin pago'}'),onTap:_busy?null:()=>_open((item['nroVenta'] as num).toInt())),
        Row(children:[TextButton(onPressed:_busy||_offset==0?null:()=>_load((_offset-20).clamp(0,_total).toInt()),child:const Text('Anterior')),
          TextButton(onPressed:_busy||_offset+_items.length>=_total?null:()=>_load(_offset+20),child:const Text('Siguiente'))]),
      ],TextButton(onPressed:_busy?null:()=>_load(_offset),child:const Text('Actualizar historial')),
    ]));
}
