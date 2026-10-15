import 'package:administracion_electoral/features/resultados/chart_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('voteDistribution', () {
    test('appends blank and null only when they have votes', () {
      final d = voteDistribution(
        lists: const [
          VoteCount(label: '1. Lista A', votes: 10),
          VoteCount(label: '2. Lista B', votes: 5),
        ],
        blank: 2,
        nullVotes: 0,
      );
      expect(d, hasLength(3));
      expect(d[0].label, '1. Lista A');
      expect(d[2].label, 'En blanco');
      expect(d[2].isList, isFalse);
    });

    test('omits blank and null when both are zero', () {
      final d = voteDistribution(
        lists: const [VoteCount(label: '1. Lista A', votes: 3)],
        blank: 0,
        nullVotes: 0,
      );
      expect(d, hasLength(1));
      expect(d.single.isList, isTrue);
    });

    test('includes nulls with the right flag', () {
      final d = voteDistribution(lists: const [], blank: 0, nullVotes: 4);
      expect(d, hasLength(1));
      expect(d.single.label, 'Nulos');
      expect(d.single.isList, isFalse);
    });
  });
}
