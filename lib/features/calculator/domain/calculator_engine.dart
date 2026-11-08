class CalculatorEngine {
  const CalculatorEngine._();

  static double evaluate(String expression) {
    final normalized = _normalize(expression.trim());
    if (normalized.isEmpty) throw const FormatException('اكتب عملية حسابية.');
    final parser = _ExpressionParser(normalized);
    final result = parser.parse();
    if (!result.isFinite) throw const FormatException('النتيجة خارج النطاق.');
    return result;
  }

  static String _normalize(String value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    var result = value
        .replaceAll('٫', '.')
        .replaceAll('٬', '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/');
    for (var i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], '$i');
    }
    return result;
  }
}

class _ExpressionParser {
  _ExpressionParser(this.input);

  final String input;
  int _index = 0;

  double parse() {
    final result = _expression();
    _skipSpaces();
    if (_index != input.length) _invalid();
    return result;
  }

  double _expression() {
    var value = _term();
    while (true) {
      _skipSpaces();
      if (_take('+')) {
        value += _term();
      } else if (_take('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _factor();
    while (true) {
      _skipSpaces();
      if (_take('*')) {
        value *= _factor();
      } else if (_take('/')) {
        final divisor = _factor();
        if (divisor == 0) {
          throw const FormatException('لا يمكن القسمة على صفر.');
        }
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _factor() {
    _skipSpaces();
    if (_take('+')) return _factor();
    if (_take('-')) return -_factor();
    if (_take('(')) {
      final value = _expression();
      _skipSpaces();
      if (!_take(')')) _invalid();
      return value;
    }
    return _number();
  }

  double _number() {
    _skipSpaces();
    final start = _index;
    var hasDigit = false;
    var hasPoint = false;
    while (_index < input.length) {
      final character = input[_index];
      if (character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57) {
        hasDigit = true;
        _index++;
      } else if (character == '.' && !hasPoint) {
        hasPoint = true;
        _index++;
      } else {
        break;
      }
    }
    if (!hasDigit) _invalid();
    final value = double.tryParse(input.substring(start, _index));
    if (value == null || !value.isFinite) _invalid();
    return value;
  }

  bool _take(String character) {
    if (_index >= input.length || input[_index] != character) return false;
    _index++;
    return true;
  }

  void _skipSpaces() {
    while (_index < input.length && input[_index].trim().isEmpty) {
      _index++;
    }
  }

  Never _invalid() => throw const FormatException('صيغة العملية غير صحيحة.');
}
