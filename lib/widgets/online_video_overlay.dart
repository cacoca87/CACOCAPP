import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../providers/online_video_provider.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';
import '../utils/geometria_del_video.dart';
import '../services/share_service.dart';
import '../styles/app_theme.dart';
import 'letra_sincronizada.dart';
import 'mini_player.dart';

/// Muestra el video de YouTube que esté sonando (si hay uno), en
/// pantalla completa o achicado en una barra fija abajo -- según
/// `OnlineVideoProvider.minimizado`. Se coloca directo en el `Stack` de
/// `PantallaPrincipal`, NO como una ruta de `Navigator`: así el video
/// sigue sonando sin importar qué sección esté mirando el usuario, en
/// vez de destruirse apenas se toca "atrás".
///
/// Hay un SOLO `YoutubePlayer`, siempre montado, y lo único que cambia
/// entre un modo y el otro es su posición y tamaño. Usar dos widgets
/// distintos (uno por modo) fue el bug original: Flutter los trata como
/// elementos distintos del árbol, así que al minimizar destruía el
/// WebView y creaba otro, perdiendo la reproducción.
///
/// Tener un solo widget NO alcanza por sí solo: Flutter también tiene
/// que reconocerlo como "el mismo" entre un estado y el otro. Por eso,
/// al tocar este archivo hay tres reglas que no se pueden romper:
///
///   1. El reproductor siempre lleva `_claveReproductor`. Sin clave,
///      Flutter empareja los hijos del `Stack` por su posición en la
///      lista -- y el reproductor cambia de índice entre un modo y el
///      otro -- así que lo destruiría y volvería a crear.
///   2. El reproductor siempre es un `AnimatedPositioned`; nunca se
///      alterna con `Positioned`. Son tipos distintos, y cambiar de
///      tipo también lo destruye.
///   3. Ningún control de la app se dibuja ENCIMA del reproductor. El
///      reproductor es un WebView, o sea una vista nativa de Android
///      que recibe los toques por su cuenta. Se probó en el celular que
///      NO alcanzan: ni un `IgnorePointer` alrededor, ni un
///      `GestureDetector` alrededor, ni una capa transparente por
///      encima. En los tres casos el WebView se quedaba con el toque y
///      los botones de la app no respondían. Por eso, en el modo chico
///      los controles van AL LADO del video, como hermanos suyos dentro
///      del `Stack` de afuera, donde sí funcionan siempre.
///
/// Además, el paquete trae dos comportamientos propios que compiten con
/// los de la app y hay que dejar apagados: su botón de pantalla
/// completa (`showFullscreenButton`, apagado en
/// `online_video_provider.dart`) y su pantalla completa por gesto
/// vertical (`enableFullScreenOnVerticalDrag`, apagado más abajo). Con
/// el segundo prendido, deslizar hacia arriba sobre el video abría una
/// pantalla completa SUYA -- sin el encabezado ni la letra de la app --
/// y encima se quedaba con todos los gestos verticales.
class OnlineVideoOverlay extends StatefulWidget {
  const OnlineVideoOverlay({super.key});

  @override
  State<OnlineVideoOverlay> createState() => _OnlineVideoOverlayState();
}

class _OnlineVideoOverlayState extends State<OnlineVideoOverlay> {
  // Las medidas viven en `utils/geometria_del_video.dart`, junto con
  // las cuentas que las usan. Acá estaban repetidas, y tener el mismo
  // número en dos lugares es exactamente lo que causó el fallo de la
  // barra montándose encima del mini reproductor: uno cambió y el otro
  // no.

  // Ver la regla 1 del comentario de arriba.
  static const _claveReproductor = ValueKey('reproductor-youtube');

  // La letra del video que se está mirando. Se guarda el Future (en vez
  // de pedirlo dentro del `build`) para no disparar una búsqueda nueva
  // en cada refresco del provider, que son muchos: uno por cada cambio
  // de estado del reproductor.
  String? _videoIdDeLaLetra;
  Future<Lyrics>? _futuroLetra;

  Future<Lyrics> _letraDe(OnlineVideoProvider p) {
    if (_futuroLetra == null || _videoIdDeLaLetra != p.videoId) {
      _videoIdDeLaLetra = p.videoId;
      // `urlCancion` va vacío a propósito: sirve para leer la letra
      // incrustada en un MP3, y acá no hay archivo, es un video.
      _futuroLetra = LyricsService.instance.getLyrics(
        title: p.titulo,
        artist: p.autor,
        urlCancion: '',
        // Lo que dura el video descarta las letras de otras canciones
        // que se llaman igual -- ver `utils/eleccion_letra.dart`.
        duracion: p.duracion,
      );
    }
    return _futuroLetra!;
  }

  /// Por dónde va el video, como un `Stream<Duration>` ESTABLE.
  ///
  /// Se guarda en vez de armarlo dentro del `build` porque
  /// `videoStateStream.map(...)` devuelve un flujo NUEVO cada vez que
  /// se lo pide. Quien lo escucha compara si le cambiaron el flujo para
  /// saber si tiene que volver a engancharse: con uno nuevo en cada
  /// refresco, la letra se desenganchaba y se volvía a enganchar todo
  /// el tiempo, por nada.
  ///
  /// El controlador se reutiliza entre videos (se le pide que cargue
  /// otro, no se crea uno nuevo), así que este flujo sirve igual para
  /// todos: lo único que hay que vigilar es que el controlador sea el
  /// mismo de antes.
  YoutubePlayerController? _controladorDeLaPosicion;
  Stream<Duration>? _posicionDelVideo;

  Stream<Duration> _posicionDe(YoutubePlayerController controller) {
    if (_posicionDelVideo == null || _controladorDeLaPosicion != controller) {
      _controladorDeLaPosicion = controller;
      _posicionDelVideo = controller.videoStateStream.map((e) => e.position);
    }
    return _posicionDelVideo!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineVideoProvider>();
    final controller = provider.controller;
    if (controller == null) return const SizedBox.shrink();

    final minimizado = provider.minimizado;
    final padding = MediaQuery.of(context).padding;
    // El mini reproductor desaparece cuando no hay ninguna canción de la
    // biblioteca cargada, así que su alto no siempre está ocupado: si se
    // descontara igual, la barra del video quedaría flotando con un
    // hueco debajo. Se usa `select` y no `watch` para que el overlay se
    // rehaga solo cuando este booleano cambia, y no en cada latido del
    // reproductor.
    final hayMiniPlayer =
        context.select<PlayerProvider, bool>((p) => p.currentSong != null);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Las cuentas de dónde va cada cosa viven en
        // `utils/geometria_del_video.dart`, con sus tests: son
        // aritmética pura, y es la parte de este archivo que de verdad
        // puede salir mal. Ya salió mal una vez --la barra chica se le
        // montaba encima al mini reproductor con la letra agrandada-- y
        // acá adentro no había forma de comprobarlo, porque el widget
        // entero lleva un WebView que no arranca fuera de un celular.
        //
        // El alto del mini reproductor sale del PROPIO mini reproductor
        // y no de un número escrito a mano: crece con la escala de
        // texto del sistema, y si los dos no salieran del mismo lugar,
        // volvería justo ese fallo.
        final geo = calcularGeometriaDelVideo(
          pantalla: Size(constraints.maxWidth, constraints.maxHeight),
          margenesDelSistema: padding,
          altoDelMiniReproductor:
              hayMiniPlayer ? MiniPlayer.altoTotal(context) : 0,
        );
        final rectBarra = geo.barra;
        final rectVideoChico = geo.videoChico;
        final rectCompleto = geo.videoCompleto;

        final rectActual = minimizado ? rectVideoChico : rectCompleto;

        // El reproductor, solo. Sin nada encima (ver regla 3).
        final reproductor = ClipRRect(
          borderRadius: BorderRadius.circular(minimizado ? 6 : 0),
          child: StreamBuilder<YoutubePlayerValue>(
            stream: controller.stream,
            builder: (context, snapshot) {
              final valor = snapshot.data;
              if (!minimizado && valor != null && valor.hasError) {
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
              return YoutubePlayer(
                controller: controller,
                enableFullScreenOnVerticalDrag: false,
                autoFullScreen: false,
              );
            },
          ),
        );

        final posicionado = AnimatedPositioned(
          key: _claveReproductor,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          left: rectActual.left,
          top: rectActual.top,
          width: rectActual.width,
          height: rectActual.height,
          child: reproductor,
        );

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Fondo oscuro de pantalla completa -- SOLO cuando no está
              // minimizado, para no bloquear toques al resto de la app.
              if (!minimizado)
                Positioned.fill(child: Container(color: AppTheme.ink)),
              if (!minimizado) _Header(provider: provider),

              // Fondo de la barra chica. Va ANTES del reproductor para
              // quedar por debajo de él. Tocarlo también agranda.
              if (minimizado)
                Positioned.fromRect(
                  rect: rectBarra,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => provider.expandir(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceRaised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.amber.withValues(alpha: 0.45)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              posicionado,

              // Título y botones: arrancan DESPUÉS del video, así que
              // nunca se superponen con él (ver regla 3).
              if (minimizado)
                Positioned(
                  left: rectVideoChico.right + 10,
                  // El borde derecho sale de la barra y no de un número
                  // suelto: si los dos no salen del mismo lugar, se
                  // desfasan en cuanto uno cambie.
                  right: constraints.maxWidth - rectBarra.right + 8,
                  top: rectBarra.top,
                  height: altoDeLaBarraDelVideo,
                  child: _ControlesBarra(provider: provider),
                ),

              // Debajo del video, en pantalla completa, quedaba un hueco
              // negro enorme. Ahora se llena con la letra, si se
              // encuentra.
              if (!minimizado)
                Positioned.fromRect(
                  // Sale de la misma cuenta que el video, así nunca se
                  // le monta encima ni pide un alto negativo --que no es
                  // un aviso: es un error dibujado en la pantalla--.
                  rect: geo.zonaDeLaLetra,
                  child: _PanelLetra(
                    futuro: _letraDe(provider),
                    controller: controller,
                    posicion: _posicionDe(controller),
                    videoId: provider.videoId,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Título, autor y botones de la barra chica. Son widgets normales de
/// Flutter ubicados AL LADO del video, nunca encima: es la única forma
/// comprobada de que los toques no se los quede el WebView.
class _ControlesBarra extends StatelessWidget {
  final OnlineVideoProvider provider;
  const _ControlesBarra({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.expandir(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(
                    color: AppTheme.paper,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.autor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.small.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.open_in_full_rounded,
              color: AppTheme.paper, size: 20),
          tooltip: "Agrandar",
          visualDensity: VisualDensity.compact,
          onPressed: () => provider.expandir(),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppTheme.mutedInk, size: 22),
          tooltip: "Cerrar",
          visualDensity: VisualDensity.compact,
          onPressed: () => provider.cerrar(),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final OnlineVideoProvider provider;
  const _Header({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.paper, size: 28),
                tooltip: "Minimizar",
                onPressed: () => provider.minimizar(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.paper,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      provider.autor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.small.copyWith(color: AppTheme.mutedInk),
                    ),
                  ],
                ),
              ),
              // Pasar al siguiente resultado sin tener que achicar el
              // video, volver a la busqueda y tocar otro. El avance
              // automatico al terminar ya existia; lo que faltaba era
              // poder pedirlo a mano. Va aca arriba, al lado del
              // titulo, y NO encima del video (ver la regla 3).
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: AppTheme.paper, size: 24),
                tooltip: "Siguiente video",
                onPressed:
                    provider.haySiguiente ? () => provider.siguiente() : null,
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded,
                    color: AppTheme.paper, size: 20),
                tooltip: "Compartir",
                onPressed: provider.videoId == null
                    ? null
                    : () => ShareService.instance.compartirVideoDeYoutube(
                          titulo: provider.titulo,
                          videoId: provider.videoId!,
                        ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.mutedInk, size: 22),
                tooltip: "Cerrar",
                onPressed: () => provider.cerrar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel debajo del video en pantalla completa. Muestra la letra si se
/// encuentra; si no, un texto breve explicando cómo funciona el modo
/// chico.
///
/// Cuando la letra viene con tiempos, se va resaltando al ritmo del
/// video, igual que en la pantalla de Letra de la biblioteca. Acá había
/// un comentario diciendo que eso no se podía hacer "porque la app no
/// tiene acceso confiable a la posición del reproductor de YouTube":
/// era falso. El paquete expone `videoStateStream`, que emite la
/// posición del video, y es exactamente lo que hacía falta.
class _PanelLetra extends StatelessWidget {
  final Future<Lyrics> futuro;
  final YoutubePlayerController controller;

  /// Por dónde va el video. Entra por acá y no se arma adentro para
  /// que sea siempre el MISMO flujo entre refrescos: ver
  /// `_OnlineVideoOverlayState._posicionDe`.
  final Stream<Duration> posicion;

  /// Con qué nombre se recuerda el ajuste de desfase de ESTE video.
  final String? videoId;

  const _PanelLetra({
    required this.futuro,
    required this.controller,
    required this.posicion,
    required this.videoId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Lyrics>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.amber),
            ),
          );
        }

        final letra = snapshot.data;
        if (letra == null || !letra.hayAlgo) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              'Tocá la flecha de arriba para achicar el video y seguir '
              'escuchándolo mientras usás el resto de la app. Se pausa solo '
              'si ponés a sonar otra canción.',
              textAlign: TextAlign.center,
              style: AppTheme.small.copyWith(color: AppTheme.faintInk),
            ),
          );
        }

        if (letra.estaSincronizada) {
          return LetraSincronizada(
            lineas: letra.lineas!,
            posicion: posicion,
            onTocarLinea: (tiempo) => controller.seekTo(
              seconds: tiempo.inMilliseconds / 1000,
              allowSeekAhead: true,
            ),
            // El ajuste de desfase se guarda por video.
            claveDeAjuste: videoId,
            // Menos aire arriba que en la pantalla de Letra: acá el
            // panel es la mitad de alto porque arriba está el video.
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 80),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          children: [
            Text(
              'Letra',
              style: AppTheme.small.copyWith(
                color: AppTheme.amber,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              letra.textoPlano ?? '',
              style:
                  AppTheme.body.copyWith(color: AppTheme.mutedInk, height: 1.6),
            ),
          ],
        );
      },
    );
  }
}
