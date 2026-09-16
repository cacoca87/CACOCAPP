import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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

class _YoutubeEscritorioScreenState extends State<YoutubeEscritorioScreen> {
  /// Lo que la app dice ser. Esta línea es la que hace que YouTube
  /// mande la página de escritorio en vez de la de celular.
  static const String _navegadorDeEscritorio =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  late final WebViewController _controlador;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();

    final controlador = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_navegadorDeEscritorio)
      ..setBackgroundColor(AppTheme.ink)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
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
                      child:
                          CircularProgressIndicator(color: AppTheme.amber),
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
