String money(num value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final fromRight = rounded.length - i;
    buffer.write(rounded[i]);
    if (fromRight > 1 && fromRight % 3 == 1) buffer.write(',');
  }
  return '${buffer.toString()} VND';
}

String shortTime(DateTime? value) {
  if (value == null) return 'Never';
  final h = value.hour.toString().padLeft(2, '0');
  final m = value.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
