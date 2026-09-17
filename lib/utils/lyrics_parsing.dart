/// Una línea de letra sincronizada: en qué momento de la canción
/// aparece, y el texto.
class LineaLetra {
  final Duration tiempo;
  final String texto;
  const LineaLetra(this.tiempo, this.texto);
}

/// Saca ruido típico de títulos de YouTube ("(Official Video)",
/// "[Lyrics]", "(Audio)", "HD", etc.) que hace fallar la búsqueda
/// exacta de letras en lrclib. No toca el título real de la canción en
/// la UI, solo se usa para buscar la letra.
///
/// Extraída de `LyricsService` (donde vivía como `_limpiarTitulo`)
/// para poder testearla en aislamiento -- es lógica pura, sin red ni
/// caché de por medio.
String limpiarTituloParaBuscarLetra(String titulo) {
  var limpio = titulo;
  final patronesRuido = [
    RegExp(r'\(\s*official\s*(music\s*)?video\s*\)', caseSensitive: false),
    RegExp(r'\(\s*official\s*audio\s*\)', caseSensitive: false),
    RegExp(r'\(\s*official\s*lyric[s]?\s*video\s*\)', caseSensitive: false),
    RegExp(r'\(\s*video\s*oficial\s*\)', caseSensitive: false),
    RegExp(r'\(\s*audio\s*oficial\s*\)', caseSensitive: false),
    RegExp(r'\[\s*official\s*video\s*\]', caseSensitive: false),
    RegExp(r'\(\s*lyrics?\s*\)', caseSensitive: false),
    RegExp(r'\[\s*lyrics?\s*\]', caseSensitive: false),
    RegExp(r'\(\s*audio\s*\)', caseSensitive: false),
    RegExp(r'\(\s*visualizer\s*\)', caseSensitive: false),
    // Muy común en esta biblioteca, que está llena de reediciones:
    // "Whole Lotta Love - Remaster", "Five Years - 2012 Remaster",
    // "Kashmir (Remastered)". El año va suelto porque cambia en cada
    // disco. Sin sacar esto, lrclib no encuentra la canción aunque la
    // tenga, porque la busca con un nombre que nadie usa.
    RegExp(
        r'[\(\[]?\s*((19|20)\d{2}\s*)?remaster(ed|izado)?(\s*(19|20)\d{2})?\s*'
        r'(version)?\s*[\)\]]?',
        caseSensitive: false),
    RegExp(r'\s*-\s*$'),
    // "(feat. Fulano)" / "(ft. Fulano)": el invitado no forma parte del
    // nombre de la canción en las bases de letras.
    RegExp(r'[\(\[]\s*(feat|ft)\.?\s[^\)\]]*[\)\]]', caseSensitive: false),
    RegExp(r'\b(hd|4k|full hd|hq)\b', caseSensitive: false),
  ];
  for (final patron in patronesRuido) {
    limpio = limpio.replaceAll(patron, '');
  }
  return limpio.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Parsea el formato LRC (`[mm:ss.xx] texto de la línea`) que devuelve
/// lrclib para letras sincronizadas. Extraída de `LyricsService`
/// (donde vivía como `_parsearLrc`) por el mismo motivo que
/// [limpiarTituloParaBuscarLetra].
List<LineaLetra> parsearLrc(String contenido) {
  // Minutos y segundos con uno o dos dígitos: hay archivos LRC que
  // escriben "[1:23]" en vez de "[01:23]", y con el patrón estricto esa
  // línea no coincidía con NADA, así que se perdía entera.
  final regex = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  final lineas = <LineaLetra>[];

  for (final linea in contenido.split('\n')) {
    final coincidencias = regex.allMatches(linea).toList();
    if (coincidencias.isEmpty) continue;

    final texto = linea.replaceAll(regex, '').trim();
    if (texto.isEmpty) continue;

    for (final m in coincidencias) {
      final minutos = int.parse(m.group(1)!);
      final segundosVal = int.parse(m.group(2)!);
      final fraccion = m.group(3);
      final milisegundos = fraccion == null
          ? 0
          : int.parse(fraccion.padRight(3, '0').substring(0, 3));

      lineas.add(LineaLetra(
        Duration(
            minutes: minutos, seconds: segundosVal, milliseconds: milisegundos),
        texto,
      ));
    }
  }

  lineas.sort((a, b) => a.tiempo.compareTo(b.tiempo));
  return lineas;
}
