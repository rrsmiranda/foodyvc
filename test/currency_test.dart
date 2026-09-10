import 'package:app_idade18/core/utils/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatBrl', () {
    expect(formatBrl(0), r'R$ 0,00');
    expect(formatBrl(6.5), r'R$ 6,50');
    expect(formatBrl(18.9), r'R$ 18,90');
    expect(formatBrl(1234.5), r'R$ 1.234,50');
    expect(formatBrl(1234567.89), r'R$ 1.234.567,89');
    expect(formatBrl(-4.2), r'-R$ 4,20');
  });
}
