import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Resultado de búsqueda ya adaptado a lo que necesita la UI de
/// `dual_search_screen.dart`. Se mantiene esta forma (en vez de exponer
/// directamente el `Video` de youtube_explode_dart) para que el resto
/// de la app no dependa de los tipos internos del paquete.
class YoutubeVideoResult {
  final String videoId;
  final String title;
  final String author;
  final String lengthSeconds; // formateado "m:ss", para mostrar en la UI
  final int lengthInSeconds; // crudo, para ordenar/filtrar
  final String viewCount; // formateado "1234 vistas"
  final String thumbnailUrl;

  YoutubeVideoResult({
    required this.videoId,
    required this.title,
    required this.author,
    required this.lengthSeconds,
    required this.lengthInSeconds,
    required this.viewCount,
    required this.thumbnailUrl,
  });

  factory YoutubeVideoResult.fromVideo(Video video) {
    final segundos = video.duration?.inSeconds ?? 0;
    final minutos = segundos ~/ 60;
    final segundosRestantes = segundos % 60;
    return YoutubeVideoResult(
      videoId: video.id.value,
      title: video.title,
      author: video.author,
      lengthSeconds: '$minutos:${segundosRestantes.toString().padLeft(2, '0')}',
      lengthInSeconds: segundos,
      viewCount: '${video.engagement.viewCount} vistas',
      thumbnailUrl: video.thumbnails.highResUrl,
    );
  }
}

/// Busca videos en YouTube. Solo BUSCA: la reproducción la hace el
/// reproductor oficial embebido (`OnlineVideoProvider` +
/// `online_video_overlay.dart`), no esta clase.
///
/// Este archivo tenía además toda una cadena para extraer la URL del
/// audio y reproducirlo con el motor propio de la app, encadenando tres
/// métodos (resolución directa en el celular, un servidor proxy propio
/// en Render, e instancias públicas de Invidious). Se borró entera
/// porque quedó inalcanzable: desde que la Búsqueda Online reproduce en
/// el reproductor embebido, ya no se crea ninguna canción con id `yt_`,
/// que era la única forma de entrar a ese camino. Además nunca iba a
/// volver a funcionar de forma confiable -- el motivo de fondo (los PO
/// Tokens de YouTube) está explicado en CAMBIOS.md.
class YoutubeService {
  static final YoutubeService instance = YoutubeService._internal();
  YoutubeService._internal();

  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<YoutubeVideoResult>> buscarVideos(String query) async {
    try {
      final resultados = await _yt.search.search(query);
      // Antes se filtraban los videos de más de 12 minutos y se
      // ordenaba de más corto a más largo -- tenía sentido cuando la
      // app extraía y bufferizaba el audio ella misma (los mixes/shows
      // largos agotaban el buffer). Desde que la reproducción pasa por
      // el reproductor oficial embebido de YouTube (que maneja su
      // propio buffer, igual que la app real), ese límite ya no
      // protege de nada -- solo escondía resultados válidos (un
      // recital, un álbum completo en un video) sin motivo.
      return resultados.map(YoutubeVideoResult.fromVideo).toList();
    } catch (_) {
      return [];
    }
  }
}
