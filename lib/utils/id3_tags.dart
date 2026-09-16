/// Lee un tag de texto de los metadatos de un MP3.
///
/// Vive aparte de `id3_cover_service.dart`, y sin nada de red ni disco
/// adentro, para poder probarlo -- mismo criterio que `rss_parser.dart`
/// o `nombre_archivo_parser.dart`. Antes esta lógica estaba escrita dos
/// veces, una para el álbum y otra para el artista, idénticas salvo la
/// clave.
///
/// El paquete `id3` no siempre devuelve lo mismo para un tag: a veces
/// es texto, a veces un mapa con la clave `text`, y a veces algo que
/// solo se puede convertir a texto. Por eso se contemplan los tres
/// casos en vez de asumir uno: un MP3 con un tag guardado de forma rara
/// tiraría un error de tipo en medio de la lista de canciones.
String? leerTagDeTexto(Map<String, dynamic>? tags, String clave) {
  if (tags == null || !tags.containsKey(clave)) return null;
  final valor = tags[clave];

  String? texto;
  if (valor is String) {
    texto = valor;
  } else if (valor is Map && valor.containsKey('text')) {
    texto = valor['text']?.toString();
  } else {
    texto = valor?.toString();
  }

  if (texto == null) return null;
  final limpio = texto.trim();
  return limpio.isEmpty ? null : limpio;
}
