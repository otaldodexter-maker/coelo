import 'package:coelo_superadmin/core/isolates/superadmin_compute.dart';
import 'package:flutter_test/flutter_test.dart';

int _sumSquares(List<int> values) {
  return values.fold<int>(0, (total, value) => total + value * value);
}

void main() {
  group('runSuperadminComputation', () {
    test('runs CPU-style work away from widget build code', () async {
      final result = await runSuperadminComputation<List<int>, int>(
        debugLabel: 'sum-squares',
        task: _sumSquares,
        message: const [1, 2, 3, 4],
      );

      expect(result, 30);
    });
  });
}
