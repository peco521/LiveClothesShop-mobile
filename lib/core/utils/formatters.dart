/// Formato de dinero y fechas de la app.
///
/// El backend envía `Decimal` como número o como texto (`"45.00"`), igual que la
/// web Angular (`number | string`), por eso todo se normaliza con [toDouble].
double toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

int toInt(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

/// Mismo criterio que la web (`Intl.NumberFormat('es-BO', currency USD code)`).
String money(Object? value) {
  final amount = toDouble(value);
  final text = amount.abs().toStringAsFixed(2);
  final parts = text.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '${amount < 0 ? '-' : ''}USD $buffer,${parts[1]}';
}

String _two(int value) => value.toString().padLeft(2, '0');

DateTime? _parse(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// `dd/MM/yyyy · HH:mm` (fechas ISO del backend).
String fechaHora(Object? value) {
  final date = _parse(value);
  if (date == null) return '—';
  return '${_two(date.day)}/${_two(date.month)}/${date.year} · ${_two(date.hour)}:${_two(date.minute)}';
}

String fecha(Object? value) {
  final date = _parse(value);
  if (date == null) return '—';
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

/// `hh:mm` a partir de `"11:00:00"` o de una fecha ISO.
String hora(Object? value) {
  final text = value?.toString() ?? '';
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
  if (match != null)
    return '${_two(int.parse(match.group(1)!))}:${match.group(2)}';
  final date = _parse(value);
  if (date == null) return '—';
  return '${_two(date.hour)}:${_two(date.minute)}';
}

/// Etiquetas de estado del backend en lenguaje del cliente.
String etiquetaVenta(String? estado) => switch (estado) {
  'registrada' => 'Registrada',
  'anulada' => 'Anulada',
  _ => 'Sin estado',
};

String etiquetaPago(String? estado) => switch (estado) {
  'aprobado' => 'Pago aprobado',
  'pendiente' => 'Pago pendiente',
  'rechazado' => 'Pago rechazado',
  _ => 'Sin pago',
};

String etiquetaReserva(String? estado) => switch (estado) {
  'pendiente' => 'Pendiente',
  'confirmada' => 'Confirmada',
  'atendida' => 'Atendida',
  'cancelada' => 'Cancelada',
  'vencida' => 'Vencida',
  _ => 'Sin estado',
};
