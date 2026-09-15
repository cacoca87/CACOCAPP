import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Estado del video de YouTube que se está reproduciendo en la app (si
/// hay alguno), sea en pantalla completa o minimizado en la burbuja
/// flotante. Vive a nivel de toda la app (no atado a ninguna
/// pantalla/ruta de `Navigator`) para que sobreviva la navegación --
/// antes, el video se destruía apenas se tocaba "atrás" desde Búsqueda
/// Online, perdiendo la reproducción por completo.
class OnlineVideoProvider extends ChangeNotifier {
  YoutubePlayerController? _controller;
  String? _videoId;
  String _titulo = '';
  String _autor = '';
  bool _minimizado = false;

  YoutubePlayerController? get controller => _controller;
  String? get videoId => _videoId;
  String get titulo => _titulo;
  String get autor => _autor;
  bool get minimizado => _minimizado;
  bool get hayVideo => _controller != null;

  void reproducir(
      {required String videoId,
      required String titulo,
      required String autor}) {
    if (_videoId == videoId && _controller != null) {
      // Ya es el mismo video que estaba sonando (ej. lo tenías
      // minimizado y volviste a tocarlo en los resultados) -- no hace
      // falta recrear nada, solo expandir. Si estaba pausado (por
      // ejemplo, por la auto-pausa al poner a sonar otra canción), se
      // reanuda también -- tocar "play" en un resultado siempre debería
      // dejarlo sonando, no expandido y pausado sin explicación.
      _controller!.playVideo();
      _minimizado = false;
      notifyListeners();
      return;
    }

    _controller?.close();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        // Apagado a propósito: este botón dispara el sistema de
        // pantalla completa INTERNO del paquete (maneja su propio
        // overlay por separado, vía OverlayPortal) -- que compite con
        // nuestro propio sistema de expandir/minimizar (burbuja
        // arrastrable) y terminaba superponiéndose con él, descentrado.
        // Como ya tenemos nuestra propia forma de "agrandar" el video
        // (tocando la burbuja), no hace falta el botón nativo también.
        showFullscreenButton: false,
        playsInline: true,
        strictRelatedVideos: true,
      ),
    );
    _videoId = videoId;
    _titulo = titulo;
    _autor = autor;
    _minimizado = false;
    notifyListeners();
  }

  /// Achica el video a la burbuja flotante -- sigue sonando.
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

  /// Cierra el video del todo (deja de sonar, desaparece la burbuja).
  void cerrar() {
    _controller?.close();
    _controller = null;
    _videoId = null;
    _minimizado = false;
    notifyListeners();
  }

  /// Se llama cuando arranca a sonar audio de la biblioteca/Jamendo/
  /// descargas -- pausa el video para no tener dos cosas sonando a la
  /// vez sin que el usuario lo haya pedido explícitamente.
  void pausarPorOtraReproduccion() {
    _controller?.pauseVideo();
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }
}
