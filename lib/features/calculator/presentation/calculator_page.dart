import 'package:flutter/material.dart';

import '../domain/calculator_engine.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  static const _buttons = [
    'مسح',
    '⌫',
    '÷',
    '×',
    '7',
    '8',
    '9',
    '−',
    '4',
    '5',
    '6',
    '+',
    '1',
    '2',
    '3',
    '=',
    '0',
    '.',
    '(',
    ')',
  ];

  String _expression = '';
  String? _result;
  String? _error;
  bool _justEvaluated = false;

  void _press(String button) {
    setState(() {
      _error = null;
      if (button == 'مسح') {
        _expression = '';
        _result = null;
        _justEvaluated = false;
        return;
      }
      if (button == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _result = null;
        _justEvaluated = false;
        return;
      }
      if (button == '=') {
        try {
          final result = CalculatorEngine.evaluate(_expression);
          _result = _format(result);
          _expression = _result!;
          _justEvaluated = true;
        } on FormatException catch (error) {
          _error = error.message;
          _result = null;
        }
        return;
      }
      final isOperator = const {'+', '−', '×', '÷'}.contains(button);
      if (_justEvaluated && !isOperator) _expression = '';
      _justEvaluated = false;
      _result = null;
      _expression += button == '−' ? '-' : button;
    });
  }

  String _format(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsPrecision(12).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > 600
            ? 520.0
            : constraints.maxWidth;
        return Center(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 130),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Text(
                            _expression.isEmpty ? '0' : _expression,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        if (_result != null)
                          Text(
                            _result!,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: colors.primary),
                          ),
                        if (_error != null)
                          Text(
                            _error!,
                            textAlign: TextAlign.start,
                            style: TextStyle(color: colors.error),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    itemCount: _buttons.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.4,
                        ),
                    itemBuilder: (context, index) {
                      final button = _buttons[index];
                      final special = const {
                        'مسح',
                        '⌫',
                        '÷',
                        '×',
                        '−',
                        '+',
                        '=',
                      }.contains(button);
                      return FilledButton.tonal(
                        onPressed: () => _press(button),
                        style: FilledButton.styleFrom(
                          backgroundColor: button == '='
                              ? colors.primary
                              : special
                              ? colors.secondaryContainer
                              : colors.surface,
                          foregroundColor: button == '='
                              ? colors.onPrimary
                              : colors.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        child: Text(
                          button,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
