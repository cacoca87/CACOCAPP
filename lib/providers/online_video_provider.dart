import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Un video de la lista de resultados, con lo justo que hace falta para
/// reproducirlo y mostrar su título.
class VideoEnCola {
  final String videoId;
  final String titulo;
  final String autor;

  /// Cuánto dura el video. Se usa para pedir la letra correcta: sin
  /// este dato, buscar por nombre puede devolver la letra de otra
  /// canción que se llama igual.
  final int duracionSegundos;

  const VideoEnCola({
    required this.videoId,
    required this.titulo,
    required this.autor,
    this.duracionSegundos = 0,
  });
}

/// Estado del video de YouTube que se está reproduciendo en la app (si
/// hay alguno), sea en pantalla completa o achicado en la barra de
/// abajo. Vive a nivel de toda la app (no atado a ninguna pantalla/ruta
/// de `Navigator`) para que sobreviva la navegación -- antes, el video
/// se destruía apenas se tocaba "atrás" desde Búsqueda Online,
/// perdiendo la reproducción por completo.
class OnlineVideoProvider extends ChangeNotifier {
  YoutubePlayerController? _controller;
  String? _videoId;
  String _titulo = '';
  String _autor = '';
  bool _minimizado = false;

  /// La lista de resultados desde la que se eligió el video, para poder
  /// pasar al siguiente cuando el actual termina.
  List<VideoEnCola> _cola = const [];
  int _indiceEnCola = -1;

  StreamSubscription<YoutubePlayerValue>? _suscripcion;

  /// Evita encadenar varios saltos por el mismo final: el estado
  /// `ended` puede llegar más de una vez seguida.
  String? _videoYaTerminado;

  YoutubePlayerController? get controller => _controller;
  String? get videoId => _videoId;
  String get titulo => _titulo;
  String get autor => _autor;
  bool get minimizado => _minimizado;
  bool get hayVideo => _controller != null;

  /// Cuánto dura el video que está sonando. Lo usa la búsqueda de la
  /// letra para no traer la de otra canción que se llama igual.
  int _duracionSegundos = 0;
  Duration? get duracion =>
      _duracionSegundos > 0 ? Duration(seconds: _duracionSegundos) : null;

  /// ¿Se puede reproducir video embebido en esta plataforma?
  ///
  /// El reproductor de YouTube es un WebView, y no todas las
  /// plataformas tienen uno: Android, iOS, macOS y web sí; Windows y
  /// Linux no. Sin esta comprobación, en Windows la app reventaba al
  /// intentar crear el reproductor en vez de avisar que no se puede.
  static bool get disponible {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// ¿Hay otro video después de este en la lista de resultados?
  bool get haySiguiente =>
      _indiceEnCola >= 0 && _indiceEnCola + 1 < _cola.length;

  /// [cola] e [indice] son opcionales: si vienen, al terminar el video
  /// se pasa solo al siguiente de la lista, como haría cualquier
  /// reproductor. Sin ellos el video simplemente termina y se queda ahí.
  void reproducir({
    required String videoId,
    required String titulo,
    required String autor,
    int duracionSegundos = 0,
    List<VideoEnCola> cola = const [],
    int indice = -1,
  }) {
    if (!disponible) return;
    _cola = cola;
    _indiceEnCola = indice;
    _videoYaTerminado = null;
    _duracionSegundos = duracionSegundos;

    if (_controller != null) {
      if (_videoId == videoId) {
        // Es el mismo video que ya estaba cargado (ej. lo tenías
        // achicado y volviste a tocarlo en los resultados). Si estaba
        // pausado -- por ejemplo, por la auto-pausa al poner a sonar
        // otra canción -- se reanuda: tocar "play" en un resultado
        // siempre debería dejarlo sonando, no expandido y pausado sin
        // explicación.
        _controller!.playVideo();
      } else {
        // Video DISTINTO: se le pide al reproductor que ya existe que
        // cargue el nuevo, en vez de crear otro controlador.
        //
        // Crear uno nuevo NO funcionaba: `YoutubePlayer` solo mira el
        // color de fondo en su `didUpdateWidget` e ignora por completo
        // que le cambien el controlador (verificado en el código del
        // paquete). Como el widget se reutiliza a propósito -- lleva
        // una `Key` fija para que la reproducción no se corte al
        // achicar, ver `online_video_overlay.dart` -- se quedaba
        // mostrando el video anterior para siempre.
        //
        // Reusar el controlador además evita destruir y rearmar el
        // WebView en cada cambio de video.
        _controller!.loadVideoById(videoId: videoId);
      }
      _videoId = videoId;
      _titulo = titulo;
      _autor = autor;
      _minimizado = false;
      notifyListeners();
      return;
    }

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        // Apagado a propósito: este botón dispara el sistema de
        // pantalla completa INTERNO del paquete, que compite con el
        // nuestro y termina superponiéndose. Ver también
        // `enableFullScreenOnVerticalDrag` en
        // `online_video_overlay.dart`, que es el otro camino del
        // paquete hacia lo mismo.
        showFullscreenButton: false,
        playsInline: true,
        strictRelatedVideos: true,
      ),
    );
    _escucharFinDelVideo();
    _videoId = videoId;
    _titulo = titulo;
    _autor = autor;
    _minimizado = false;
    notifyListeners();
  }

  void _escucharFinDelVideo() {
    _suscripcion?.cancel();
    _suscripcion = _controller?.stream.listen((valor) {
      // Se anota el estado para saber, al bloquear la pantalla, si el
      // video estaba sonando o si lo habías pausado vos.
      _ultimoEstado = valor.playerState;

      if (valor.playerState != PlayerState.ended) return;
      // `ended` puede repetirse; sin esta guarda un solo final podría
      // saltearse varios videos de un tirón.
      if (_videoYaTerminado == _videoId) return;
      _videoYaTerminado = _videoId;
      siguiente(conservarTamano: true);
    });
  }

  // ===== Seguir sonando con la pantalla bloqueada =====
  //
  // El reproductor de YouTube vive dentro de una vista web. Cuando se
  // bloquea la pantalla, la página queda oculta y el propio reproductor
  // de YouTube se pausa solo: es una decisión de su código, no de
  // Android.
  //
  // Contra eso sí se puede hacer algo, porque el control del video no
  // va por dentro de la página: va por la API oficial de YouTube, que
  // atiende igual aunque la página esté oculta. O sea que se le puede
  // volver a dar "play".
  //
  // Eso es lo que hace esto: mientras la app está en segundo plano y el
  // video estaba sonando, se le insiste con `playVideo()`. Si YouTube
  // se pausó por estar oculto, vuelve solo.
  //
  // HONESTAMENTE: esto puede no alcanzar. Si Android llega a suspender
  // la vista web entera (no solo ocultarla), ningún "play" la
  // despierta. Eso depende del celular y de la versión de Android, y es
  // algo que solo se sabe probándolo en el aparato.

  Timer? _insistirEnSonar;
  PlayerState? _ultimoEstado;

  /// Cuántas veces se insiste antes de rendirse. A ~0,9 s cada una, son
  /// unos tres minutos: si a esa altura no volvió, no va a volver.
  static const int _maxIntentos = 200;

  /// La app se fue al fondo (pantalla bloqueada, u otra app adelante).
  void alIrseAlFondo() {
    if (_controller == null) return;
    // Si lo habías pausado vos, se respeta: no se pone a sonar solo.
    if (_ultimoEstado != PlayerState.playing) return;

    _insistirEnSonar?.cancel();
    var intentos = 0;
    _insistirEnSonar =
        Timer.periodic(const Duration(milliseconds: 900), (temporizador) {
      if (_controller == null || intentos++ >= _maxIntentos) {
        temporizador.cancel();
        _insistirEnSonar = null;
        return;
      }
      _controller?.playVideo();
    });
  }

  /// La app volvió al frente: ya no hace falta insistir.
  void alVolverAlFrente() {
    _insistirEnSonar?.cancel();
    _insistirEnSonar = null;
  }

  /// Pasa al siguiente video de la lista de resultados, si hay.
  ///
  /// [conservarTamano] mantiene el modo en el que estabas. Lo usa el
  /// avance automático al terminar un video: si estabas mirando la barra
  /// chica mientras navegabas la app, que el siguiente te saltara a
  /// pantalla completa solo sería molesto. En cambio, si lo pedís vos a
  /// mano, se expande como cualquier video que elegís.
  void siguiente({bool conservarTamano = false}) {
    if (!haySiguiente) return;
    final estabaMinimizado = _minimizado;
    final proximo = _cola[_indiceEnCola + 1];
    reproducir(
      videoId: proximo.videoId,
      titulo: proximo.titulo,
      autor: proximo.autor,
      duracionSegundos: proximo.duracionSegundos,
      cola: _cola,
      indice: _indiceEnCola + 1,
    );
    if (conservarTamano && estabaMinimizado) {
      _minimizado = true;
      notifyListeners();
    }
  }

  /// Achica el video a la barra de abajo -- sigue sonando.
  void minimizar() {
    if (_controller == null) return;
    _minimizado = true;
    notifyListeners();
  }

  /// Vuelve a pantalla completa.
  void expandir() {
    if (_controller == null) return;
    _minimizado = false;
    notifyListeners();
  }

  /// Cierra el video del todo (deja de sonar, desaparece la barra).
  void cerrar() {
    _insistirEnSonar?.cancel();
    _insistirEnSonar = null;
    _ultimoEstado = null;
    _suscripcion?.cancel();
    _suscripcion = null;
    _controller?.close();
    _controller = null;
    _videoId = null;
    _cola = const [];
    _indiceEnCola = -1;
    _videoYaTerminado = null;
    _minimizado = false;
    notifyListeners();
  }

  /// Pausa el video, si hay uno. La usa `PlayerProvider` cuando arranca
  /// otra reproducción y cuando vence el temporizador de apagado.
  void pausar() {
    _controller?.pauseVideo();
  }

  @override
  void dispose() {
    _insistirEnSonar?.cancel();
    _suscripcion?.cancel();
    _controller?.close();
    super.dispose();
  }
}
