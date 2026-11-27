import 'package:flutter_test/flutter_test.dart';
import 'package:nerdmaxxing_client/utils/compact_number_formatter.dart';

void main() {
  test('keeps values below the compact threshold unchanged', () {
    expect(formatCompactCount(9999), '9999');
  });

  test('formats compact values with one useful decimal', () {
    expect(formatCompactCount(10000), '10K');
    expect(formatCompactCount(12394), '12.4K');
    expect(formatCompactCount(12000), '12K');
  });

  test('rolls rounded values up to the next suffix', () {
    expect(formatCompactCount(999500), '1M');
    expect(formatCompactCount(1000000), '1M');
    expect(formatCompactCount(12394000), '12.4M');
  });
}