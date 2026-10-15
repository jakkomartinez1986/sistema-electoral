import '../constants.dart';

/// Resumen de una elección tal como lo entrega el backend a las apps.
///
/// Es un DTO de lectura. No incluye votos ni participación.
class ElectionSummary {
  const ElectionSummary({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.status,
    this.opensAt,
    this.closesAt,
    this.timeZone = kDefaultTimeZone,
    this.configVersion = 1,
  });

  final String id;
  final String name;
  final String academicYear;
  final ElectionStatus status;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final String timeZone;
  final int configVersion;

  factory ElectionSummary.fromJson(Map<String, Object?> json) {
    DateTime? parseDate(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toUtc();

    return ElectionSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      academicYear: json['academic_year'] as String,
      status: ElectionStatus.fromDb(json['status'] as String),
      opensAt: parseDate(json['opens_at']),
      closesAt: parseDate(json['closes_at']),
      timeZone: (json['time_zone'] as String?) ?? kDefaultTimeZone,
      configVersion: (json['config_version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'academic_year': academicYear,
        'status': status.name,
        'opens_at': opensAt?.toUtc().toIso8601String(),
        'closes_at': closesAt?.toUtc().toIso8601String(),
        'time_zone': timeZone,
        'config_version': configVersion,
      };

  /// ¿La elección está abierta *según la hora configurada*, no la del reloj
  /// del dispositivo? La decisión definitiva es del servidor; esto solo sirve
  /// para avisar al operador.
  bool isOpenAt(DateTime instant) {
    if (status != ElectionStatus.open) return false;
    final t = instant.toUtc();
    if (opensAt != null && t.isBefore(opensAt!)) return false;
    if (closesAt != null && t.isAfter(closesAt!)) return false;
    return true;
  }
}
