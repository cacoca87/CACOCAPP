import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../providers/online_video_provider.dart';
import '../services/share_service.dart';
import '../styles/app_theme.dart';

/// Muestra el video de YouTube que esté sonando (si hay uno), en
/// pantalla completa o como burbuja flotante arrastrable -- según
/// `OnlineVideoProvider.minimizado`. Se coloca directo en el `Stack`
/// de `PantallaPrincipal`, NO como una ruta de `Navigator`: así el
/// video sigue sonando sin importar qué sección esté mirando el
/// usuario, en vez de destruirse apenas se toca "atrás".
///
/// IMPORTANTE (bug real arreglado acá): la primera versión de esto
/// usaba DOS widgets `YoutubePlayer` distintos -- uno para pantalla
/// completa, otro para la burbuja -- y mostraba uno u otro según el
/// estado. Para Flutter eso son dos elementos totalmente distintos del
/// árbol: al minimizar, destruía el WebView de pantalla completa y
/// creaba uno nuevo para la burbuja (y viceversa al expandir),
/// perdiendo la reproducción en el camino -- exactamente el bug
/// reportado ("se achica pero no suena", "al volver se corta"). Ahora
/// hay un SOLO `YoutubePlayer`, siempre montado, y lo que cambia es
/// solo su posición/tamaño -- el WebView nunca se destruye, así que la
/// reproducción nunca se corta.
///
/// Tener un solo widget NO alcanza por sí solo: Flutter también tiene
/// que poder reconocerlo como "el mismo" entre un estado y el otro. Si
/// cambia de tipo o de índice dentro del `Stack`, lo destruye igual
/// aunque el código lo escriba una sola vez. Por eso, al tocar este
/// archivo hay dos reglas que no se pueden romper:
///   1. El reproductor siempre lleva `_claveReproductor`.
///   2. El reproductor siempre es un `AnimatedPositioned` (nunca se
///      alterna con `Positioned`).
/// Romper cualquiera de las dos hace volver el bug de "se congela y
/// deja de sonar al minimizar".
class OnlineVideoOverlay extends StatefulWidget {
  const OnlineVideoOverlay({super.key});

  @override
  State<OnlineVideoOverlay> createState() => _OnlineVideoOverlayState();
}

class _OnlineVideoOverlayState extends State<OnlineVideoOverlay> {
  static const double _anchoBurbuja = 160;
  static const double _altoBurbuja = 96;
  static const double _margenBurbuja = 12;
  static const double _margenSobreMiniPlayer = 96;

  // Posición de la burbuja cuando está minimizada -- null hasta que el
  // usuario la arrastra por primera vez, ahí se usa la esquina
  // inferior derecha por defecto.
  Offset? _posicionBurbuja;

  // Mientras se está arrastrando activamente, la posición se aplica sin
  // animación -- si se anima también durante el arrastre, cada
  // micro-movimiento del dedo dispara una animación de 260ms detrás de
  // la anterior y la burbuja se siente "pegajosa"/con retraso en vez de
  // seguir al dedo. Solo se anima la transición deliberada entre
  // burbuja y pantalla completa.
  bool _arrastrando = false;

  // Identifica al reproductor dentro del `Stack` de abajo. Es
  // OBLIGATORIA, no un detalle: ese Stack tiene 4 hijos en pantalla
  // completa (fondo, encabezado, reproductor, instrucciones) y 1 solo
  // al minimizar, así que el reproductor cambia de índice. Sin una
  // clave, Flutter empareja los hijos por posición en la lista, ve un
  // tipo distinto en el índice 0 y destruye/recrea el reproductor --
  // lo que mata el WebView de Android y deja el video congelado y sin
  // sonido. Con la clave lo reconoce y lo reutiliza aunque se mueva.
  static const _claveReproductor = ValueKey('reproductor-youtube');

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineVideoProvider>();
    final controller = provider.controller;
    if (controller == null) return const SizedBox.shrink();

    final minimizado = provider.minimizado;

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoPantalla = constraints.maxWidth;
        final altoPantalla = constraints.maxHeight;

        final rectBurbuja = _calcularRectBurbuja(anchoPantalla, altoPantalla);
        // Pantalla completa: usa buena parte de la altura disponible
        // (no solo el ancho a 16:9, que en un celular alto dejaba un
        // hueco negro grande abajo y daban ganas de rotar el celular
        // para verlo más grande -- rotar rompía todo, ver más abajo).
        final altoHeader = 64.0 + MediaQuery.of(context).padding.top;
        final altoDisponible =
            altoPantalla - altoHeader - 90; // deja lugar para el texto de abajo
        var altoVideoCompleto = altoDisponible.clamp(0.0, altoPantalla * 0.55);
        var anchoVideoCompleto = altoVideoCompleto * 16 / 9;
        if (anchoVideoCompleto > anchoPantalla) {
          anchoVideoCompleto = anchoPantalla;
          altoVideoCompleto = anchoVideoCompleto * 9 / 16;
        }
        final rectCompleto = Rect.fromLTWH(
          (anchoPantalla - anchoVideoCompleto) / 2,
          altoHeader,
          anchoVideoCompleto,
          altoVideoCompleto,
        );

        final rectActual = minimizado ? rectBurbuja : rectCompleto;

        final reproductor = Container(
          clipBehavior: Clip.antiAlias,
          decoration: minimizado
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.amber.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : const BoxDecoration(),
          child: Stack(
            children: [
              // Mientras está minimizado, los controles nativos de
              // YouTube quedan demasiado chicos para tocarlos bien --
              // se ignoran los toques acá y se usa el GestureDetector
              // de afuera (tap = expandir, arrastre = mover). En
              // pantalla completa SÍ reciben los toques normalmente.
              IgnorePointer(
                ignoring: minimizado,
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
                          style:
                              AppTheme.body.copyWith(color: AppTheme.mutedInk),
                        ),
                      );
                    }
                    return YoutubePlayer(controller: controller);
                  },
                ),
              ),
              if (minimizado)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => provider.cerrar(),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        );

        final gestos = GestureDetector(
          // `opaque` mientras está en burbuja: sin esto el detector usa
          // `deferToChild`, o sea que solo recibe toques si algo de
          // ADENTRO los recibe -- y adentro está el `IgnorePointer` que
          // justamente desactiva el WebView. La burbuja no capturaba
          // nada y los toques pasaban de largo a la lista de resultados
          // que está debajo: arrastrarla hacía scroll de la lista en vez
          // de moverla. Expandido NO va opaco, porque ahí los toques
          // tienen que llegar a los controles del reproductor.
          behavior: minimizado
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
          onTap: minimizado ? () => provider.expandir() : null,
          // Se separa el "empieza a arrastrar"/"termina de arrastrar"
          // para saber cuándo animar la posición y cuándo no (ver
          // `_arrastrando` más arriba).
          onPanStart:
              minimizado ? (_) => setState(() => _arrastrando = true) : null,
          onPanEnd:
              minimizado ? (_) => setState(() => _arrastrando = false) : null,
          onPanUpdate: minimizado
              ? (details) => setState(() {
                    final base = _posicionBurbuja ??
                        Offset(rectBurbuja.left, rectBurbuja.top);
                    final nueva = base + details.delta;
                    _posicionBurbuja = Offset(
                      nueva.dx.clamp(
                          0.0,
                          (anchoPantalla - _anchoBurbuja)
                              .clamp(0.0, double.infinity)),
                      nueva.dy.clamp(
                          0.0,
                          (altoPantalla - _altoBurbuja)
                              .clamp(0.0, double.infinity)),
                    );
                  })
              : null,
          child: reproductor,
        );

        // Mientras se arrastra, la duración baja a cero: la posición se
        // aplica al instante y la burbuja sigue al dedo 1 a 1. El resto
        // del tiempo (incluida la transición burbuja <-> pantalla
        // completa) se anima suave.
        //
        // OJO: tiene que seguir siendo SIEMPRE un `AnimatedPositioned`.
        // Antes se alternaba entre `Positioned` (arrastrando) y
        // `AnimatedPositioned` (resto) -- como son tipos distintos,
        // Flutter destruía y recreaba todo lo de adentro al empezar a
        // arrastrar, matando el WebView y cortando el video. Cambiar
        // solo la duración logra lo mismo sin tocar el tipo.
        final posicionado = AnimatedPositioned(
          key: _claveReproductor,
          duration:
              _arrastrando ? Duration.zero : const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          left: rectActual.left,
          top: rectActual.top,
          width: rectActual.width,
          height: rectActual.height,
          child: gestos,
        );

        // Envuelto en Material (transparente, sin pintar nada por su
        // cuenta) para que el título/subtítulo/instrucciones tengan un
        // estilo de texto real del que heredar -- sin esto, Flutter les
        // aplica su estilo de emergencia (amarillo subrayado, bien
        // visible a propósito) porque quedan sin ningún ancestro
        // `Material`/`DefaultTextStyle` real. Eso era justo el
        // recuadro amarillo feo reportado.
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Fondo oscuro de pantalla completa -- SOLO cuando no
              // está minimizado, para no bloquear toques al resto de
              // la app mientras está en la burbuja.
              if (!minimizado)
                Positioned.fill(child: Container(color: AppTheme.ink)),
              if (!minimizado) _Header(provider: provider),
              posicionado,
              if (!minimizado)
                Positioned(
                  left: 0,
                  right: 0,
                  top: rectCompleto.bottom + 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Tocá la flecha para minimizar y seguir escuchando mientras '
                      'usás el resto de la app -- se pausa solo si ponés a sonar '
                      'otra canción. La burbuja se puede arrastrar.',
                      textAlign: TextAlign.center,
                      style: AppTheme.small.copyWith(color: AppTheme.faintInk),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Rect _calcularRectBurbuja(double anchoPantalla, double altoPantalla) {
    final maxX = (anchoPantalla - _anchoBurbuja).clamp(0.0, double.infinity);
    final maxY = (altoPantalla - _altoBurbuja).clamp(0.0, double.infinity);
    final base = _posicionBurbuja ??
        Offset(anchoPantalla - _anchoBurbuja - _margenBurbuja,
            altoPantalla - _altoBurbuja - _margenSobreMiniPlayer);
    return Rect.fromLTWH(
      base.dx.clamp(0.0, maxX),
      base.dy.clamp(0.0, maxY),
      _anchoBurbuja,
      _altoBurbuja,
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
