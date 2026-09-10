/// Formata um valor em reais no padrao pt-BR, sem depender de `intl`.
///
/// `12` -> `R$ 12,00` · `1234.5` -> `R$ 1.234,50`.
String formatBrl(double value) {
  final bool negative = value < 0;
  final String digits = value.abs().toStringAsFixed(2);
  final int dot = digits.indexOf('.');
  final String intPart = digits.substring(0, dot);
  final String cents = digits.substring(dot + 1);

  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write('.');
    grouped.write(intPart[i]);
  }

  return '${negative ? '-' : ''}R\$ $grouped,$cents';
}
