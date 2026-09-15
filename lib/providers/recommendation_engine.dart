import '../models/song.dart';

/// Elige canciones para "Recomendado para ti": prioriza las que
/// todavía no aparecen en el historial de escucha, y si ya se
/// escuchó todo, cae de nuevo sobre la biblioteca completa en vez de
/// devolver una lista vacía.
///
/// Extraída de `PlayerProvider.getRecommendations` para poder
/// testearla sin depender de `MyAudioHandler`/`AudioPlayer` (el
/// resto de `PlayerProvider` sí depende de eso, esta lógica no).
List<Song> calcularRecomendaciones(
  List<Song> allSongs,
  Iterable<String> historialIds, {
  int cantidad = 10,
}) {
  if (allSongs.isEmpty) return [];

  final historial = historialIds.toSet();
  final noEscuchadas =
      allSongs.where((song) => !historial.contains(song.id)).toList();
  final candidatas =
      noEscuchadas.isNotEmpty ? noEscuchadas : List<Song>.from(allSongs);

  final copia = List<Song>.from(candidatas)..shuffle();
  return copia.take(cantidad).toList();
}

/// Ordena ids de canción de más a menos reproducciones. Extraída de
/// `PlayerProvider.masEscuchadasIds` por el mismo motivo que
/// [calcularRecomendaciones].
List<String> ordenarPorMasEscuchadas(Map<String, int> conteoReproducciones) {
  final entradas = conteoReproducciones.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entradas.map((e) => e.key).toList();
}
