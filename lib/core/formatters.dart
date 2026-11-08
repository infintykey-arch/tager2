String normalizeDigits(String value) {
  final result = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      result.writeCharCode(rune - 0x0660 + 0x30);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      result.writeCharCode(rune - 0x06F0 + 0x30);
    } else {
      result.writeCharCode(rune);
    }
  }
  return result.toString();
}

String _normalizedDecimalInput(String value) {
  return normalizeDigits(value.trim())
      .replaceAll('٬', '')
      .replaceAll('٫', '.')
      .replaceAll(',', '');
}

int? parseMoneyMinor(String value) {
  final normalized = _normalizedDecimalInput(value);
  if (normalized.isEmpty ||
      !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
    return null;
  }

  final parts = normalized.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return whole * 100 + fraction;
}

double? parseQuantity(String value) {
  var normalized = _normalizedDecimalInput(value);
  if (normalized.startsWith('.')) normalized = '0$normalized';
  if (normalized.isEmpty ||
      !RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(normalized)) {
    return null;
  }
  return double.tryParse(normalized);
}

String formatMoneyMinor(int amount) {
  final whole = amount ~/ 100;
  final fractional = (amount % 100).toString().padLeft(2, '0');
  return '$whole.$fractional ج.م';
}

String formatQuantity(double quantity) {
  final rounded = quantity.toStringAsFixed(3);
  return rounded
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} - $hour:$minute';
}
