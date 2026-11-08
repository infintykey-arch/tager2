import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/features/calculator/domain/calculator_engine.dart';

void main() {
  test('يطبق أولوية الضرب والقسمة قبل الجمع والطرح', () {
    expect(CalculatorEngine.evaluate('12+3*4-8/2'), 20);
  });

  test('يدعم الأقواس والإشارات السالبة', () {
    expect(CalculatorEngine.evaluate('-(2+3)*4'), -20);
  });

  test('يقبل الأرقام العربية والفاصل العشري العربي', () {
    expect(CalculatorEngine.evaluate('١٢٫٥ + ٢٫٥'), 15);
  });

  test('يرفض القسمة على صفر بصياغة مفهومة', () {
    expect(
      () => CalculatorEngine.evaluate('7 / 0'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('القسمة على صفر'),
        ),
      ),
    );
  });

  test('يرفض العملية غير المكتملة بدل إرجاع نتيجة صامتة', () {
    expect(
      () => CalculatorEngine.evaluate('4 +'),
      throwsA(isA<FormatException>()),
    );
  });
}
