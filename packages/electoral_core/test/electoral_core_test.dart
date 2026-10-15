import 'package:electoral_core/electoral_core.dart';
import 'package:test/test.dart';

void main() {
  group('CedulaEcuador', () {
    test('acepta una cédula válida de Pichincha', () {
      expect(CedulaEcuador.isValid('1710034065'), isTrue);
    });

    test('normaliza espacios y guiones', () {
      expect(CedulaEcuador.normalize('171 003 4065'), '1710034065');
      expect(CedulaEcuador.normalize('171-003-4065'), '1710034065');
    });

    test('rechaza longitud incorrecta', () {
      expect(CedulaEcuador.isValid('171003406'), isFalse);
      expect(CedulaEcuador.isValid('17100340651'), isFalse);
    });

    test('rechaza provincia inexistente', () {
      expect(CedulaEcuador.isValid('9910034065'), isFalse);
    });

    test('rechaza tercer dígito >= 6', () {
      expect(CedulaEcuador.isValid('1760034065'), isFalse);
    });

    test('rechaza dígito verificador incorrecto', () {
      expect(CedulaEcuador.isValid('1710034066'), isFalse);
    });
  });

  group('StudentCodeRules', () {
    const rules = StudentCodeRules.defaults;

    test('acepta códigos alfanuméricos', () {
      expect(rules.isValid('ABC123'), isTrue);
      expect(rules.isValid('2024-001_A'), isTrue);
    });

    test('rechaza espacios y símbolos raros', () {
      expect(rules.isValid('ABC 123'), isFalse);
      expect(rules.isValid('ABC#123'), isFalse);
    });

    test('respeta longitudes mínima y máxima', () {
      expect(rules.isValid('AB'), isFalse);
      expect(rules.isValid(List.filled(21, 'A').join()), isFalse);
    });
  });

  group('BallotOption', () {
    test('lista requiere candidateListId', () {
      expect(
        () => BallotOption.fromDb(optionType: 'list'),
        throwsArgumentError,
      );
      expect(
        BallotOption.fromDb(optionType: 'list', candidateListId: 'L1')
            .candidateListId,
        'L1',
      );
    });

    test('payload no incluye identidad y usa valores canónicos', () {
      expect(const BallotOption.blank().toPayload(), {
        'option_type': 'blank',
        'candidate_list_id': null,
      });
      expect(const BallotOption.nullVote().type, BallotOptionType.nullVote);
    });
  });

  group('ElectionStatus', () {
    test('solo open acepta papeletas', () {
      expect(ElectionStatus.open.acceptsBallots, isTrue);
      expect(ElectionStatus.closing.acceptsBallots, isFalse);
      expect(ElectionStatus.closed.acceptsBallots, isFalse);
    });

    test('fromDb rechaza valores desconocidos', () {
      expect(() => ElectionStatus.fromDb('nope'), throwsArgumentError);
    });
  });

  group('CastBallotResult', () {
    test('interpreta un voto aceptado', () {
      final r = CastBallotResult.fromJson({
        'operation_id': 'op-1',
        'status': 'accepted',
      });
      expect(r.accepted, isTrue);
      expect(r.duplicate, isFalse);
      expect(r.errorCode, isNull);
    });

    test('interpreta un duplicado con conflicto', () {
      final r = CastBallotResult.fromJson({
        'operation_id': 'op-2',
        'status': 'conflict',
        'error_code': 'duplicate_participation',
        'duplicate': true,
      });
      expect(r.accepted, isFalse);
      expect(r.status, SyncOperationStatus.conflict);
      expect(r.duplicate, isTrue);
      expect(r.errorCode, 'duplicate_participation');
    });
  });

  group('StaffProfile', () {
    test('deriva capacidades desde los roles (lista de cadenas)', () {
      final p = StaffProfile.fromJson({
        'id': 'u1',
        'full_name': 'Ana Pérez',
        'institution_id': 'i1',
        'roles': ['admin', 'operator'],
      });
      expect(p.isAdmin, isTrue);
      expect(p.isOperator, isTrue);
      expect(p.isTutor, isFalse);
      expect(p.isStaff, isTrue);
    });

    test('admite roles anidados (fila de user_roles)', () {
      final p = StaffProfile.fromJson({
        'id': 'u2',
        'full_name': 'Luis',
        'roles': [
          {'role': 'tutor'},
        ],
      });
      expect(p.roles, {UserRole.tutor});
    });

    test('sin roles no es operativo', () {
      final p = StaffProfile.fromJson({
        'id': 'u3',
        'full_name': 'Sin rol',
      });
      expect(p.isStaff, isFalse);
    });
  });

  group('SupabaseConfig', () {
    test('isConfigured exige URL y clave no vacías', () {
      expect(
        const SupabaseConfig(url: '', publishableKey: '').isConfigured,
        isFalse,
      );
      expect(
        const SupabaseConfig(url: 'https://x.supabase.co', publishableKey: 'k')
            .isConfigured,
        isTrue,
      );
    });
  });

  group('PadronVerifier', () {
    const salt = '00000000-0000-0000-0000-000000000001';

    test('coincide con los valores generados por el servidor (cédula)', () {
      expect(
        PadronVerifier.cedula(salt: salt, cedula: '1710034065'),
        '3b1720171150d9dc4f94a2ea6cacee1df7dc136bb4261ec649ca56ee8432cb36',
      );
    });

    test('coincide con los valores generados por el servidor (PIN)', () {
      expect(
        PadronVerifier.pin(salt: salt, pin: '1234'),
        'b350006d2297f4bfe0030d679a2294e68de9aa2d527657a08aa47f73a2208d1f',
      );
    });

    test('normaliza espacios y guiones en la cédula', () {
      expect(PadronVerifier.normalizeCedula('171-003 4065'), '1710034065');
      expect(
        PadronVerifier.cedula(salt: salt, cedula: '171 003-4065'),
        PadronVerifier.cedula(salt: salt, cedula: '1710034065'),
      );
    });
  });

  group('VoterLookup', () {
    const salt = '00000000-0000-0000-0000-000000000001';
    // Verificadores reales del servidor (ver grupo PadronVerifier).
    const cedulaVerifier =
        '3b1720171150d9dc4f94a2ea6cacee1df7dc136bb4261ec649ca56ee8432cb36';
    const pinVerifier =
        'b350006d2297f4bfe0030d679a2294e68de9aa2d527657a08aa47f73a2208d1f';

    final padron = [
      const PadronEntry(
        voterRef: 'v1',
        code: 'DEMO-001',
        cedulaVerifier: cedulaVerifier,
        pinVerifier: pinVerifier,
      ),
      const PadronEntry(voterRef: 'v2', code: 'DEMO-002'),
    ];

    test('encuentra por cédula válida', () {
      final result = VoterLookup.byCedula(
        salt: salt,
        cedula: '171 003-4065',
        padron: padron,
      );
      expect(result.status, VoterMatchStatus.found);
      expect(result.voterRef, 'v1');
    });

    test('rechaza una cédula con formato inválido', () {
      final result = VoterLookup.byCedula(
        salt: salt,
        cedula: '1710034066',
        padron: padron,
      );
      expect(result.status, VoterMatchStatus.invalidCedula);
    });

    test('no encuentra una cédula ausente del padrón', () {
      final result = VoterLookup.byCedula(
        salt: salt,
        cedula: '0102030400',
        padron: padron,
      );
      expect(result.status, VoterMatchStatus.notFound);
    });

    test('código + PIN correcto identifica al votante', () {
      final result = VoterLookup.byCode(
        salt: salt,
        code: 'demo-001',
        pin: '1234',
        padron: padron,
      );
      expect(result.status, VoterMatchStatus.found);
      expect(result.voterRef, 'v1');
    });

    test('código con PIN incorrecto devuelve badPin', () {
      final result = VoterLookup.byCode(
        salt: salt,
        code: 'DEMO-001',
        pin: '0000',
        padron: padron,
      );
      expect(result.status, VoterMatchStatus.badPin);
    });

    test('un votante sin verificadores solo se identifica por código', () {
      final result = VoterLookup.byCode(
        salt: salt,
        code: 'DEMO-002',
        pin: '',
        padron: padron,
      );
      expect(result.status, VoterMatchStatus.found);
      expect(result.voterRef, 'v2');
    });

    test('un código vacío es inválido', () {
      final result = VoterLookup.byCode(
        salt: salt,
        code: '   ',
        pin: '1234',
        padron: padron,
      );
      expect(result.status, VoterMatchStatus.invalidCode);
    });
  });

  group('DeviceBundle', () {
    test('parsea el bundle y marca votantes sin verificador', () {
      final bundle = DeviceBundle.fromJson({
        'device': {
          'device_id': 'd1',
          'device_uid': 'DEV-1',
          'label': 'Mesa 1',
        },
        'institution': {
          'id': 'i1',
          'name': 'DEMO',
          'time_zone': 'America/Guayaquil',
        },
        'assignment': {
          'election_id': 'e1',
          'voting_table_id': 't1',
          'config_version': 1,
        },
        'voting_table': {'id': 't1', 'code': 'T1', 'name': 'Mesa 1'},
        'verifier_salt': 'i1',
        'config': {
          'election': {'id': 'e1', 'name': 'Elección', 'status': 'open'},
          'lists': [
            {'id': 'l1', 'number': 1, 'name': 'Lista 1'},
          ],
          'candidates': [
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
        'config_hash': 'abc',
        'voters': [
          {
            'voter_ref': 'v1',
            'code': 'DEMO-001',
            'voting_table_id': 't1',
            'cedula_verifier': 'x',
            'pin_verifier': 'y',
          },
          {
            'voter_ref': 'v2',
            'code': 'DEMO-002',
            'voting_table_id': 't1',
            'cedula_verifier': null,
            'pin_verifier': null,
          },
        ],
        'server_time': '2026-10-13T16:18:28.846239+00:00',
      });

      expect(bundle.votingTable?.code, 'T1');
      expect(bundle.config.election.status, ElectionStatus.open);
      expect(bundle.config.candidatesOf('l1').single.fullName, 'Candidato');
      expect(bundle.voters.length, 2);
      expect(bundle.voters.first.isCodeOnly, isFalse);
      expect(bundle.voters.last.isCodeOnly, isTrue);
    });
  });
}