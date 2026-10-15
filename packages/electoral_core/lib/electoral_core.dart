/// Núcleo compartido del Sistema Electoral Estudiantil.
///
/// Solo contiene lo que de verdad conviene reutilizar entre la app de
/// administración y la de votación: constantes, modelos de transporte,
/// validaciones y formatos. Nada de interfaz ni de acceso a datos.
library;

export 'src/config/supabase_config.dart';
export 'src/constants.dart';
export 'src/models/ballot_option.dart';
export 'src/models/cast_ballot_result.dart';
export 'src/models/device_bundle.dart';
export 'src/models/election_summary.dart';
export 'src/models/staff_profile.dart';
export 'src/rpc/electoral_rpc.dart';
export 'src/validation/cedula_ecuador.dart';
export 'src/validation/padron_verifier.dart';
export 'src/validation/student_code.dart';
export 'src/validation/voter_lookup.dart';
