String formatCompactCount(int value, {int compactThreshold = 10000}) {
  if (value.abs() < compactThreshold) return value.toString();

  const suffixes = ['K', 'M', 'B', 'T', 'Q'];
  final sign = value.isNegative ? '-' : '';
  var amount = value.abs().toDouble();
  var suffixIndex = -1;

  while (amount >= 1000 && suffixIndex < suffixes.length - 1) {
    amount /= 1000;
    suffixIndex++;
  }

  late double rounded;
  while (true) {
    rounded = amount >= 100
        ? amount.roundToDouble()
        : (amount * 10).roundToDouble() / 10;
    if (rounded < 1000 || suffixIndex >= suffixes.length - 1) break;
    amount /= 1000;
    suffixIndex++;
  }

  final number = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
  return '$sign$number${suffixes[suffixIndex]}';
}