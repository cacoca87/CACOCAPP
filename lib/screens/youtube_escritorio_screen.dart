import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../main.dart';
import '../styles/app_theme.dart';

/// Abre el video en **youtube.com de verdad**, en su versión de
/// escritorio, dentro de la app.
///
/// POR QUÉ ESTO Y NO EL REPRODUCTOR DE SIEMPRE
///
/// El reproductor embebido (el que usa el resto de la app) carga la
/// versión para celulares de YouTube, y esa versión **se pausa sola**
/// cuando detecta que su página quedó oculta: es una decisión del
/// propio código de YouTube, pensada para teléfonos.
///
/// La versión de escritorio no hace eso. En una computadora se espera
/// que la música siga sonando aunque cambies de pestaña, así que no
/// trae esa lógica. Pidiéndole a YouTube la página de escritorio
/// --diciéndole que somos un navegador de computadora-- se consigue un
/// reproductor que no se pausa solo al bloquear la pantalla.
///
/// Es YouTube en vivo, el video real, sin descargar nada ni extraer
/// nada: exactamente la misma página que verías en una computadora.
///
/// QUÉ PUEDE SALIR MAL, DICHO DE FRENTE
///
/// Que Android decida suspender la vista web entera. Eso ya no depende
/// de YouTube sino del sistema y del fabricante del celular, y cambia
/// entre modelos. Si pasa, no hay forma de evitarlo desde acá.
///
/// Por eso este modo se abre aparte y no reemplaza al reproductor de
/// siempre: si no anda en un celular, el otro sigue estando.
class YoutubeEscritorioScreen extends StatefulWidget {
  final String videoId;
  final String titulo;

  const YoutubeEscritorioScreen({
    super.key,
    required this.videoId,
    required this.titulo,
  });

  @override
  State<YoutubeEscritorioScreen> createState() =>
      _YoutubeEscritorioScreenState();
}

class _YoutubeEscritorioScreenState extends State<YoutubeEscritorioScreen>
    with WidgetsBindingObserver {
  /// Lo que la app dice ser. Esta línea es la que hace que YouTube
  /// mande la página de escritorio en vez de la de celular.
  static const String _navegadorDeEscritorio =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  late final WebViewController _controlador;
  bool _cargando = true;

  /// Lo que se le inyecta a la página apenas termina de cargar.
  ///
  /// Esta es la pieza clave, y es la razón por la que este modo existe
  /// aparte: acá la página es NUESTRA (la cargamos nosotros), así que
  /// podemos ejecutarle JavaScript. Con el reproductor embebido de la
  /// otra pantalla es imposible, porque el video vive dentro de un
  /// marco de otro dominio y el navegador lo prohíbe.
  ///
  /// Qué hace: le miente a YouTube sobre si la página está a la vista.
  /// YouTube se pausa solo cuando detecta que quedó oculta; si nunca se
  /// entera, no se pausa. Además tapa el aviso de "cambió la
  /// visibilidad" antes de que su código lo reciba.
  static const String _mentirleSobreLaVisibilidad = '''
(function () {
  try {
    Object.defineProperty(document, 'hidden',
        { get: function () { return false; }, configurable: true });
    Object.defineProperty(document, 'visibilityState',
        { get: function () { return 'visible'; }, configurable: true });
    Object.defineProperty(document, 'webkitHidden',
        { get: function () { return false; }, configurable: true });
    var tapar = function (e) {
      e.stopImmediatePropagation();
    };
    document.addEventListener('visibilitychange', tapar, true);
    document.addEventListener('webkitvisibilitychange', tapar, true);
    window.addEventListener('pagehide', tapar, true);
    window.addEventListener('blur', tapar, true);
  } catch (e) {}
})();
''';

  /// Se le da "play" al video de la página directamente, sin pasar por
  /// YouTube. Si algo lo pausó, vuelve.
  static const String _volverADarlePlay = '''
(function () {
  try {
    var v = document.querySelector('video');
    if (v && v.paused) { v.play(); }
  } catch (e) {}
})();
''';

  Timer? _insistir;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _insistir?.cancel();
      _insistir = null;
      return;
    }
    // Pantalla bloqueada o app atrás: se le insiste al video para que
    // siga. Con la mentira de arriba puesta, esto casi nunca hace
    // falta -- pero si algo igual lo pausa, lo levanta.
    _insistir?.cancel();
    var intentos = 0;
    _insistir = Timer.periodic(const Duration(seconds: 1), (t) {
      if (intentos++ > 240) {
        t.cancel();
        return;
      }
      _controlador.runJavaScript(_volverADarlePlay);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Le pedimos a `audio_service` que muestre una sesión de medios por
    // este video. No es cosmético: eso levanta el servicio en primer
    // plano, que es lo que evita que Android congele la app al bloquear
    // la pantalla. Sin él, la vista web sigue viva pero el sistema
    // suspende la app entera a los pocos segundos.
    audioHandler.iniciarSesionDeVideo(
      id: 'yt_${widget.videoId}',
      titulo: widget.titulo,
      autor: 'YouTube',
    );
    final controlador = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_navegadorDeEscritorio)
      ..setBackgroundColor(AppTheme.ink)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _controlador.runJavaScript(_mentirleSobreLaVisibilidad);
            if (mounted) setState(() => _cargando = false);
          },
        ),
      );

    // Sin esto, Android exige que la persona toque la pantalla antes de
    // dejar sonar nada, y el video se queda quieto al abrirse.
    final plataforma = controlador.platform;
    if (plataforma is AndroidWebViewController) {
      plataforma.setMediaPlaybackRequiresUserGesture(false);
    }

    controlador.loadRequest(
      Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}'),
    );
    _controlador = controlador;
  }

  @override
  void dispose() {
    _insistir?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Se saca la notificación al salir de esta pantalla: si quedara,
    // Android seguiría creyendo que la app está reproduciendo algo.
    audioHandler.terminarSesionDeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.paper),
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.titulo,
          style: AppTheme.subheading.copyWith(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'YouTube en versión de escritorio. Dale play y bloqueá la '
              'pantalla: esta versión no se pausa sola como la de celular.',
              style: AppTheme.small.copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controlador),
                if (_cargando)
                  const ColoredBox(
                    color: AppTheme.ink,
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.amber),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
