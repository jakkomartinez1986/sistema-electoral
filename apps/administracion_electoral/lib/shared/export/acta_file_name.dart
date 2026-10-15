import 'acta.dart';

/// Convierte un texto en un fragmento seguro para un nombre de archivo.
///
/// Quita acentos, pasa a minúsculas y reemplaza cualquier separador por guiones.
String slugify(String value) {
  const accents = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    final replacement = accents[char];
    if (replacement != null) {
      buffer.write(replacement);
    } else if (RegExp(r'[a-z0-9]').hasMatch(char)) {
      buffer.write(char);
    } else {
      buffer.write('-');
    }
  }
  return buffer
      .toString()
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

/// Nombre sugerido del acta, p. ej. `acta-eleccion-personero-2025.pdf`.
String actaFileName(ActaData data, String extension) {
  final slug = slugify(data.electionName);
  return '${slug.isEmpty ? 'acta' : 'acta-$slug'}.$extension';
}
