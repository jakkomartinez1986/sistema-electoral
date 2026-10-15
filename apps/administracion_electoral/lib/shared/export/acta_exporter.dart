import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'acta.dart';
import 'acta_excel.dart';
import 'acta_file_name.dart';
import 'acta_pdf.dart';

/// Guarda el acta en disco mediante el diálogo nativo de "Guardar como".
///
/// Devuelve la ruta guardada, o `null` si la persona cancela el diálogo.
class ActaExporter {
  const ActaExporter();

  Future<String?> savePdf(ActaData data) async {
    final bytes = await buildActaPdf(data);
    return _save(bytes, actaFileName(data, 'pdf'), 'PDF', 'pdf');
  }

  Future<String?> saveExcel(ActaData data) async {
    final bytes = Uint8List.fromList(buildActaExcel(data));
    return _save(bytes, actaFileName(data, 'xlsx'), 'Excel', 'xlsx');
  }

  Future<String?> _save(
    Uint8List bytes,
    String suggestedName,
    String label,
    String extension,
  ) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(label: label, extensions: [extension]),
      ],
    );
    if (location == null) return null;
    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
