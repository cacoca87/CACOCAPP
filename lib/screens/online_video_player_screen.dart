import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../styles/app_theme.dart';

/// Reproduce un video de YouTube usando el reproductor OFICIAL embebido
/// de Google (vía `youtube_player_iframe`, que envuelve un WebView),
/// en vez de extraer el audio del video como hacía `YoutubeService`.
///
/// Por qué este cambio: YouTube exige desde 2024 un "PO Token" para
/// autorizar la extracción directa de audio/video -- un desafío pensado
/// específicamente para que solo un navegador real pueda resolverlo.
/// Afecta por igual a TODAS las herramientas de extracción no
/// oficiales (youtube_explode_dart, yt-dlp, youtubei.js, etc.), no es
/// un bug de esta app -- está confirmado en los issues abiertos de esos
/// proyectos, y lo comprobamos en la práctica con la cadena de 3
/// métodos de respaldo que se armó antes de esto (directo -> proxy
/// propio -> Invidious): ninguno es confiable al 100% porque los tres
/// pelean contra la misma defensa.
///
/// El WebView, en cambio, carga el reproductor real de YouTube -- el
/// mismo que corre en la app oficial y en cualquier sitio que embebe
/// videos de YouTube. Google lo mantiene y no lo bloquea porque es
/// tráfico legítimo, no una extracción -- aunque sí valida que el
/// embed esté bien formado (de ahí los errores 152/153 que se vieron
/// al armar el WebView a mano; este paquete ya resuelve esa
/// configuración correctamente, es su único propósito).
///
/// Trade-off consciente (ver CAMBIOS.md): esto NO tiene reproducción en
/// segundo plano como el resto de la app (Drive/Jamendo/descargas) --
/// necesita la pantalla abierta con el WebView activo, y mientras suena
/// se ve la interfaz de YouTube, no la nuestra. Por eso esto reemplaza
/// solo la reproducción de "Búsqueda Online"; el resto de la app sigue
/// igual.
class OnlineVideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String author;

  const OnlineVideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.author,
  });

  @override
  State<OnlineVideoPlayerScreen> createState() => _OnlineVideoPlayerScreenState();
}

class _OnlineVideoPlayerScreenState extends State<OnlineVideoPlayerScreen> {
  YoutubePlayerController? _controller;

  // youtube_player_iframe (vía webview_flutter) tiene implementación
  // oficial para Android/iOS/macOS. Web necesitaría "webview_flutter_web"
  // aparte (no se bajó sin pedirlo explícitamente), y Windows/Linux no
  // tienen implementación oficial todavía -- en cualquiera de esos
  // casos, en vez de crashear, se muestra un aviso claro.
  bool get _plataformaSoportada {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    if (_plataformaSoportada) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          playsInline: true,
          strictRelatedVideos: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final contenido = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.paper, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body.copyWith(
                          color: AppTheme.paper,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        widget.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.small.copyWith(color: AppTheme.mutedInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_plataformaSoportada || controller == null)
            const _AvisoNoSoportado()
          else
            // Centrado verticalmente en el espacio libre (en vez de
            // quedar pegado arriba con un hueco negro abajo). El
            // paquete maneja la pantalla completa por su cuenta al
            // tocar el ícono de expandir -- se activa correctamente
            // adaptándose al tamaño real de la pantalla porque todo
            // esto está envuelto en `YoutubePlayerControllerProvider`
            // más abajo (sin eso, el video quedaba flotando mal
            // posicionado en vez de expandirse de verdad).
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: StreamBuilder<YoutubePlayerValue>(
                    stream: controller.stream,
                    builder: (context, snapshot) {
                      final valor = snapshot.data;
                      if (valor != null && valor.hasError) {
                        return Container(
                          color: AppTheme.ink,
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Text(
                            'YouTube no dejó reproducir este video acá '
                            '(código ${valor.error}). Probá con otro resultado.',
                            textAlign: TextAlign.center,
                            style: AppTheme.body.copyWith(color: AppTheme.mutedInk),
                          ),
                        );
                      }
                      return YoutubePlayer(controller: controller);
                    },
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Reproduciendo con el reproductor oficial de YouTube. '
              'La pantalla necesita quedar abierta -- a diferencia del resto '
              'de tu música, esto no suena en segundo plano.',
              textAlign: TextAlign.center,
              style: AppTheme.small.copyWith(color: AppTheme.faintInk),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: controller == null
          ? contenido
          : YoutubePlayerControllerProvider(controller: controller, child: contenido),
    );
  }
}

class _AvisoNoSoportado extends StatelessWidget {
  const _AvisoNoSoportado();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.desktop_access_disabled, size: 48, color: AppTheme.mutedInk),
          const SizedBox(height: 12),
          Text(
            'El video de YouTube todavía no está disponible en esta plataforma '
            '-- probalo desde el celular (Android).',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(color: AppTheme.mutedInk),
          ),
        ],
      ),
    );
  }
}
