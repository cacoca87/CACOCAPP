import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/formato_tiempo.dart';

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
    return YoutubeVideoResult(
      videoId: video.id.value,
      title: video.title,
      author: video.author,
      lengthSeconds: duracionCortaDeSegundos(segundos),
      lengthInSeconds: segundos,
      viewCount: '${video.engagement.viewCount} vistas',
      thumbnailUrl: video.thumbnails.highResUrl,
    );
  }
}

/// Se lanza cuando la busqueda no se pudo hacer: sin internet, o
/// YouTube cambio algo y el paquete no pudo leer la respuesta. Es
/// distinto de "busque bien y no hay resultados", que antes se
/// mostraba con el mismo mensaje que "todavia no buscaste nada".
class ErrorBusquedaYoutube implements Exception {
  final String mensaje;
  const ErrorBusquedaYoutube(this.mensaje);

  @override
  String toString() => mensaje;
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
      throw const ErrorBusquedaYoutube(
        'No se pudo buscar en YouTube. Revisá tu conexión e intentá de nuevo.',
      );
    }
  }

  /// Devuelve la URL del AUDIO suelto de un video, para reproducirlo
  /// con el motor de audio de la app en vez del reproductor embebido.
  ///
  /// Por qué hace falta: el reproductor embebido de YouTube es una
  /// vista web, y Android la congela al bloquear la pantalla. Por eso
  /// el video se callaba. El audio suelto, en cambio, entra por el
  /// mismo camino que las canciones del Drive -- `just_audio` +
  /// `audio_service` -- que ya corre como servicio en primer plano y
  /// sigue sonando con la pantalla apagada, con su notificación y sus
  /// controles en la pantalla de bloqueo.
  ///
  /// Dos cosas para tener presentes:
  ///
  /// * La URL que devuelve YouTube CADUCA (unas horas) y está atada al
  ///   aparato que la pidió. Por eso se resuelve justo antes de
  ///   reproducir, cada vez, y no se guarda en ningún lado.
  /// * Esto depende de cómo YouTube arma sus enlaces hoy, que es algo
  ///   que ellos cambian sin avisar. Está probado y funcionando, pero
  ///   si algún día deja de andar, el diagnóstico está en
  ///   `tool/probar_audio_youtube.dart`: dice en dos minutos si el
  ///   problema es este o es otra cosa.
  Future<String> obtenerUrlDeAudio(String videoId) async {
    try {
      final manifiesto = await _yt.videos.streamsClient.getManifest(videoId);
      final soloAudio = manifiesto.audioOnly;
      if (soloAudio.isEmpty) {
        throw const ErrorBusquedaYoutube(
          'Este video no tiene una pista de audio que se pueda escuchar '
          'aparte. Probá con otro resultado.',
        );
      }

      // Se prefiere mp4/m4a (AAC) sobre webm/opus: los dos andan en
      // Android, pero el primero lo soporta absolutamente todo.
      final enMp4 = soloAudio
          .where((s) => s.codec.mimeType.contains('mp4'))
          .toList(growable: false);
      final elegida = enMp4.isNotEmpty
          ? enMp4.reduce((a, b) =>
              a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond ? a : b)
          : soloAudio.withHighestBitrate();

      return elegida.url.toString();
    } on ErrorBusquedaYoutube {
      rethrow;
    } catch (_) {
      throw const ErrorBusquedaYoutube(
        'No se pudo preparar el audio de este video. Puede ser la conexión, '
        'o que YouTube no lo permita. Probá con otro resultado.',
      );
    }
  }
}
