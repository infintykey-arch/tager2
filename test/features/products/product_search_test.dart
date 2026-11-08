import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/features/products/domain/product_search.dart';

void main() {
  test('يطابق الاسم عربيًا بعد التطبيع الجزئي', () {
    expect(matchesProductSearch('لبن', 'لبنة كاملة'), isTrue);
    expect(matchesProductSearch('احمر', 'أحمر'), isTrue);
  });

  test('يسمح بخطأ حرف واحد ونقص بعض الحروف', () {
    expect(matchesProductSearch('بندوره', 'طماطم بندورة'), isTrue);
    expect(matchesProductSearch('تفح', 'تفاح أخضر'), isTrue);
  });

  test('لا يوسع البحث القصير لنتائج عشوائية', () {
    expect(matchesProductSearch('م', 'مياه معدنية'), isTrue);
    expect(matchesProductSearch('ز', 'مياه معدنية'), isFalse);
  });

  test('يولد فهرسًا عربيًا مطبعًا ويغطي حرفًا ناقصًا أو مكتوبًا خطأ', () {
    final nameGrams = productSearchIndexGrams('أحمر تفاح');
    final queryGrams = productSearchQueryGrams('احمر تفح');

    expect(nameGrams, contains('اح'));
    expect(nameGrams, contains('تف'));
    expect(queryGrams, hasLength(2));
    expect(queryGrams.first, contains('اح'));
    expect(queryGrams.last, contains('تف'));
    expect(matchesProductSearch('احمر تفح', 'أحمر تفاح'), isTrue);
  });
}
