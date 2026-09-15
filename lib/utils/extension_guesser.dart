/// Adivina la extensión de archivo a partir del último segmento de la
/// RUTA de una URL (no de la URL completa) -- partir el string entero
/// por puntos podía agarrar basura de parámetros de query (ej. un
/// "1.5" dentro de "?rate=1.5"). Devuelve 'mp3' si no se puede
/// determinar nada razonable (URL sin extensión reconocible, como las
/// de streaming de YouTube).
String adivinarExtensionDeUrl(String url) {
  try {
    final segmento = Uri.parse(url)
        .pathSegments
        .lastWhere((s) => s.isNotEmpty, orElse: () => '');
    if (segmento.contains('.')) {
      final ext = segmento.split('.').last;
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
  } catch (_) {}
  return 'mp3';
}
