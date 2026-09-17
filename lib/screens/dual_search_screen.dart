import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/online_video_provider.dart';
import '../services/youtube_service.dart';
import '../styles/app_theme.dart';
import 'diagnostico_youtube_screen.dart';
import '../widgets/estado_vacio.dart';

class DualSearchScreen extends StatefulWidget {
  final VoidCallback? onVolver;

  const DualSearchScreen({super.key, this.onVolver});

  @override
  State<DualSearchScreen> createState() => _DualSearchScreenState();
}

class _DualSearchScreenState extends State<DualSearchScreen> {
  // Estos 2 campos son `static` a propósito: cuando el usuario navega
  // a otra sección (Inicio, Descubrir, etc.) esta pantalla se destruye
  // por completo y se crea una nueva la próxima vez que la abre --
  // eso es lo que hacía que la búsqueda y los resultados "desaparecieran"
  // al salir y volver a entrar. Como los `static` viven en la clase y
  // no en la instancia, sobreviven aunque el widget se destruya y se
  // vuelva a crear.
  static String _ultimaBusqueda = '';
  static List<YoutubeVideoResult> _ultimosResultados = [];

  late final TextEditingController _searchController =
      TextEditingController(text: _ultimaBusqueda);
  List<YoutubeVideoResult> _resultados = _ultimosResultados;
  bool _cargandoResultados = false;
  Timer? _debounce;

  // Se incrementa con cada búsqueda lanzada. `_debounce.cancel()` solo
  // cancela un temporizador que todavía no disparó -- no puede frenar
  // una búsqueda que ya salió a la red. Sin este contador, si escribís
  // "aerosmith" (búsqueda lenta) y después "queen" (rápida), los
  // resultados de Queen aparecen primero y los de Aerosmith los pisan
  // al llegar tarde: quedabas viendo resultados de algo que ya no
  // habías buscado.
  int _generacionBusqueda = 0;

  // Si ya se ejecuto al menos una busqueda, y el mensaje del ultimo
  // fallo. Sin estos dos, "no encontre nada" y "no pude buscar" se
  // veian igual que "todavia no buscaste".
  bool _yaBusco = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _ultimaBusqueda = query;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final generacion = ++_generacionBusqueda;

    if (query.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _ultimosResultados = [];
        _cargandoResultados = false;
        _yaBusco = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _cargandoResultados = true;
      _error = null;
    });

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final resultados = await YoutubeService.instance.buscarVideos(query);
        // Si mientras esta búsqueda estaba en la red se escribió otra
        // cosa, se descarta en vez de pisar los resultados nuevos.
        if (!mounted || generacion != _generacionBusqueda) return;
        setState(() {
          _resultados = resultados;
          _ultimosResultados = resultados;
          _cargandoResultados = false;
          _yaBusco = true;
        });
      } on ErrorBusquedaYoutube catch (e) {
        // Antes el servicio devolvia una lista vacia cuando fallaba, y
        // la pantalla mostraba "escribi el nombre de una cancion" como
        // si no hubieras buscado nada.
        if (!mounted || generacion != _generacionBusqueda) return;
        setState(() {
          _resultados = [];
          _cargandoResultados = false;
          _yaBusco = true;
          _error = e.mensaje;
        });
      }
    });
  }

  void _volver() {
    if (widget.onVolver != null) {
      widget.onVolver!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Antes esta pantalla tenía su propio PopScope acá -- quedó
    // duplicado con el que ahora maneja PantallaPrincipal para TODAS
    // las secciones (incluida esta), y los dos activos a la vez hacían
    // que "atrás" te sacara de Búsqueda Online igual aunque el video
    // de YouTube estuviera expandido (en vez de minimizarlo primero,
    // como corresponde). El PopScope de más arriba ya cubre este caso.
    return Column(
      children: [
        // Cabecera con botón de retroceso y título modificado
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppTheme.paper, size: 18),
              tooltip: "Volver",
              onPressed: _volver,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Búsqueda Online",
                style: AppTheme.heading.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Comprueba desde ESTE celular si YouTube deja bajar una
            // cancion entera. Sirve para no discutir de memoria.
            IconButton(
              icon: const Icon(Icons.troubleshoot_rounded,
                  color: AppTheme.mutedInk, size: 20),
              tooltip: 'Probar si YouTube deja bajar el audio',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DiagnosticoYoutubeScreen(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Barra de búsqueda principal sin referencias explícitas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _searchController,
              style:
                  AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 14),
              onChanged: _onSearchChanged,
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  _onSearchChanged(query);
                }
              },
              decoration: InputDecoration(
                hintText: "Buscar música o videos en YouTube...",
                hintStyle: AppTheme.body.copyWith(color: AppTheme.faintInk),
                prefixIcon: const Icon(Icons.search, color: AppTheme.amber),
                suffixIcon: IconButton(
                  tooltip: "Borrar búsqueda",
                  icon: const Icon(Icons.clear, color: AppTheme.mutedInk),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Indicador de carga
        if (_cargandoResultados)
          const LinearProgressIndicator(color: AppTheme.amber),

        const SizedBox(height: 8),

        // Listado de resultados
        // En Windows y Linux no hay WebView, así que el reproductor
        // embebido no existe. Se avisa en vez de dejar buscar cosas que
        // después no van a poder reproducirse.
        Expanded(
          child: !OnlineVideoProvider.disponible
              ? const EstadoVacio(
                  icono: Icons.desktop_access_disabled_rounded,
                  mensaje: 'La Búsqueda Online necesita el reproductor de '
                      'YouTube, que no está disponible en esta plataforma. '
                      'Funciona en Android.',
                )
              : _error != null
                  ? EstadoVacio(
                      icono: Icons.wifi_off_rounded,
                      mensaje: _error!,
                      accion: ElevatedButton.icon(
                        style: AppTheme.primaryButton,
                        onPressed: () =>
                            _onSearchChanged(_searchController.text),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    )
                  : _resultados.isEmpty
                      ? EstadoVacio(
                          icono: _yaBusco
                              ? Icons.search_off_rounded
                              : Icons.video_library_outlined,
                          // Antes los tres casos (buscando, sin
                          // resultados y todavia no buscaste) mostraban
                          // el mismo texto de "escribi algo".
                          mensaje: _cargandoResultados
                              ? 'Buscando...'
                              : _yaBusco
                                  ? 'YouTube no devolvió nada con esa '
                                      'búsqueda. Probá con otras palabras.'
                                  : 'Escribí el nombre de una canción o un '
                                      'artista para buscarlo en YouTube.',
                        )
                      : ListView.builder(
                          itemCount: _resultados.length,
                          itemBuilder: (context, index) {
                            final video = _resultados[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                leading: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        video.thumbnailUrl,
                                        width: 75,
                                        height: 50,
                                        // La miniatura que da YouTube es de
                                        // alta resolucion: sin esto se
                                        // decodificaba entera en memoria para
                                        // dibujarla en 75x50 px, una por fila.
                                        cacheWidth: (75 *
                                                MediaQuery.devicePixelRatioOf(
                                                    context))
                                            .round(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          width: 75,
                                          height: 50,
                                          color: AppTheme.surfaceLight,
                                          child: const Icon(Icons.music_video,
                                              color: AppTheme.mutedInk),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      color: Colors.black87,
                                      child: Text(
                                        video.lengthSeconds,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  video.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body.copyWith(
                                    color: AppTheme.paper,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  "${video.author} • ${video.viewCount}",
                                  style: AppTheme.small.copyWith(fontSize: 11),
                                ),
                                trailing: const Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: AppTheme.amber,
                                    size: 28),
                                // El video se pone a sonar en el overlay persistente
                                // (OnlineVideoProvider) -- NO se navega a una pantalla
                                // nueva, así el video sobrevive si después tocás
                                // "atrás" o cambiás de sección (se minimiza en vez de
                                // destruirse).
                                onTap: () {
                                  // Sin esto, el campo de búsqueda conserva el foco
                                  // mientras mirás el video, y Android deja flotando
                                  // el manipulador del cursor: una "gota" del color
                                  // primario (ámbar) dibujada POR ENCIMA del video,
                                  // porque vive en la capa de superposición de la app.
                                  FocusScope.of(context).unfocus();
                                  // Se pasa la lista entera para que, al terminar
                                  // este video, siga solo con el siguiente.
                                  context
                                      .read<OnlineVideoProvider>()
                                      .reproducir(
                                        videoId: video.videoId,
                                        titulo: video.title,
                                        autor: video.author,
                                        duracionSegundos: video.lengthInSeconds,
                                        cola: _resultados
                                            .map((r) => VideoEnCola(
                                                  videoId: r.videoId,
                                                  titulo: r.title,
                                                  autor: r.author,
                                                  duracionSegundos:
                                                      r.lengthInSeconds,
                                                ))
                                            .toList(),
                                        indice: index,
                                      );
                                },
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
