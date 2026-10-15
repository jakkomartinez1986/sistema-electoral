import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'acta.dart';

String _stamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _percent(int value, int total) {
  if (total <= 0) return '0.0%';
  return '${(value / total * 100).toStringAsFixed(1)}%';
}

const List<PdfColor> _barColors = [
  PdfColor.fromInt(0xFF2563EB),
  PdfColor.fromInt(0xFF0C6B62),
  PdfColor.fromInt(0xFFB03D0B),
  PdfColor.fromInt(0xFF7C3AED),
  PdfColor.fromInt(0xFF8A5A0B),
  PdfColor.fromInt(0xFFBE185D),
  PdfColor.fromInt(0xFF0E7490),
  PdfColor.fromInt(0xFF4D7C0F),
];

/// Barra horizontal para el informe gráfico dentro del PDF.
pw.Widget _bar(String label, int votes, int total, PdfColor color) {
  const track = 260.0;
  final fraction = total <= 0 ? 0.0 : (votes / total).clamp(0.0, 1.0);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 150,
          child: pw.Text(
            label,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.SizedBox(
          width: track,
          height: 12,
          child: pw.Stack(
            children: [
              pw.Container(
                width: track,
                height: 12,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
              pw.Container(
                width: track * fraction,
                height: 12,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          '$votes (${_percent(votes, total)})',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
}

/// Genera el acta de resultados en PDF (agregados, sin identidad del votante).
Future<Uint8List> buildActaPdf(ActaData data) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        pw.Text(
          'ACTA DE RESULTADOS',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          data.institutionName,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Elección: ${data.electionName}'),
        pw.Text('Estado: ${data.statusLabel}'),
        if (data.closedAt != null)
          pw.Text('Fecha de cierre: ${_stamp(data.closedAt!)}'),
        pw.Text('Emitido: ${_stamp(data.generatedAt)}'),
        pw.SizedBox(height: 16),
        pw.Text(
          'Escrutinio',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const ['N.º', 'Lista', 'Votos', '% válidos'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: [
            for (final row in data.orderedByVotes)
              [
                '${row.number}',
                row.name,
                '${row.votes}',
                _percent(row.votes, data.validVotes),
              ],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: const ['Concepto', 'Total'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
          },
          data: [
            ['Votos válidos', '${data.validVotes}'],
            ['Votos en blanco', '${data.blank}'],
            ['Votos nulos', '${data.nullVotes}'],
            ['Total escrutado', '${data.cast}'],
            if (data.participation != null)
              ['Participación (registros)', '${data.participation}'],
            if (data.issued != null)
              ['Operaciones registradas', '${data.issued}'],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Informe gráfico (sobre el total escrutado)',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < data.orderedByVotes.length; i++)
              _bar(
                '${data.orderedByVotes[i].number}. '
                '${data.orderedByVotes[i].name}',
                data.orderedByVotes[i].votes,
                data.cast,
                _barColors[i % _barColors.length],
              ),
            if (data.blank > 0)
              _bar('En blanco', data.blank, data.cast, PdfColors.grey500),
            if (data.nullVotes > 0)
              _bar('Nulos', data.nullVotes, data.cast, PdfColors.grey700),
          ],
        ),
        pw.SizedBox(height: 28),
        pw.Text(
          'Firmas de la junta receptora',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 40),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signature('Presidente/a'),
            _signature('Secretario/a'),
            _signature('Vocal'),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Documento generado por el Sistema Electoral Estudiantil. Contiene '
          'únicamente agregados; no incluye la identidad de los votantes.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _signature(String label) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.center,
  children: [
    pw.Container(width: 150, height: 1, color: PdfColors.grey700),
    pw.SizedBox(height: 4),
    pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
  ],
);
