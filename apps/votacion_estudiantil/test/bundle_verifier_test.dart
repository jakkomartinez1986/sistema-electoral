import 'package:electoral_core/electoral_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:votacion_estudiantil/core/bundle/bundle_verifier.dart';

Map<String, Object?> _bundle({
  List<Object?>? lists,
  List<Object?>? candidates,
  List<Object?>? voters,
  String? votingTableId = 't1',
}) => {
  'device': {'device_id': 'd1', 'device_uid': 'DEV-1', 'label': 'Mesa 1'},
  'institution': {'id': 'i1', 'name': 'DEMO', 'time_zone': 'America/Guayaquil'},
  'assignment': {
    'election_id': 'e1',
    'voting_table_id': votingTableId,
    'config_version': 1,
  },
  'voting_table': {'id': 't1', 'code': 'T1', 'name': 'Mesa 1'},
  'verifier_salt': 'i1',
  'config': {
    'election': {'id': 'e1', 'name': 'Elección', 'status': 'open'},
    'lists': lists ?? [
      {'id': 'l1', 'number': 1, 'name': 'Lista 1'},
    ],
    'candidates': candidates ?? [
      {
        'id': 'c1',
        'list_id': 'l1',
        'full_name': 'Candidato',
        'position': 'Presidente',
        'order_index': 0,
      },
    ],
  },
  'config_version': 1,
  'config_hash': 'abcdef0123456789',
  'voters': voters ?? [
    {
      'voter_ref': 'v1',
      'code': 'DEMO-001',
      'voting_table_id': 't1',
      'cedula_verifier': 'x',
      'pin_verifier': 'y',
    },
  ],
  'server_time': '2026-10-13T16:18:28.846239+00:00',
};

void main() {
  test('un paquete completo se considera listo', () {
    final report = verifyBundle(DeviceBundle.fromJson(_bundle()));
    expect(report.isReady, isTrue);
    expect(report.listCount, 1);
    expect(report.candidateCount, 1);
    expect(report.voterCount, 1);
    expect(report.votersWithoutVerifier, 0);
    expect(report.shortHash, 'abcdef012345');
  });

  test('avisa de padrón vacío y de votantes sin verificador', () {
    final report = verifyBundle(
      DeviceBundle.fromJson(
        _bundle(
          voters: [
            {
              'voter_ref': 'v1',
              'code': 'DEMO-001',
              'voting_table_id': 't1',
              'cedula_verifier': null,
              'pin_verifier': null,
            },
          ],
        ),
      ),
    );
    expect(report.isReady, isFalse);
    expect(report.votersWithoutVerifier, 1);
    expect(report.warnings.any((w) => w.contains('sin cédula ni PIN')), isTrue);
  });

  test('detecta candidatos sin lista y votantes fuera de la mesa', () {
    final report = verifyBundle(
      DeviceBundle.fromJson(
        _bundle(
          candidates: [
            {
              'id': 'c9',
              'list_id': 'l-desconocida',
              'full_name': 'Huérfano',
              'position': 'Presidente',
            },
          ],
          voters: [
            {
              'voter_ref': 'v1',
              'code': 'DEMO-001',
              'voting_table_id': 't-otra',
              'cedula_verifier': 'x',
              'pin_verifier': 'y',
            },
          ],
        ),
      ),
    );
    expect(report.isReady, isFalse);
    expect(report.warnings.any((w) => w.contains('sin una lista válida')), isTrue);
    expect(report.warnings.any((w) => w.contains('fuera de la mesa')), isTrue);
  });
}
