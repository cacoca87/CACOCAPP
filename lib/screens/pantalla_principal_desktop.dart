import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/barra_lateral.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/mini_player.dart';
import '../widgets/online_video_overlay.dart';
import '../widgets/song_options_menu.dart';
import '../widgets/song_cover.dart';

/// Layout de escritorio/tablet (panel lateral fijo + panel de "ahora
/// suena" a la derecha, en vez del `Drawer` + `MiniPlayer` abajo que
/// usa la versión de celular). Extraído de `pantalla_principal.dart`
/// para bajar el tamaño de ese archivo -- es una rama autocontenida
/// que no comparte lógica con la versión de celular más allá de los
/// datos que recibe por parámetro.
class PantallaPrincipalDesktop extends StatelessWidget {
  final String seccionActiva;
  final String bibliotecaSeleccionada;
  final List<String> bibliotecas;
  final TextEditingController controladorNuevaBib;
  final Widget contenidoPrincipal;
  final ValueChanged<String> onCambiarSeccion;
  final ValueChanged<String> onSeleccionarBiblioteca;
  final VoidCallback onCrearBiblioteca;
  final Future<void> Function(String) onEliminarBiblioteca;

  const PantallaPrincipalDesktop({
    super.key,
    required this.seccionActiva,
    required this.bibliotecaSeleccionada,
    required this.bibliotecas,
    required this.controladorNuevaBib,
    required this.contenidoPrincipal,
    required this.onCambiarSeccion,
    required this.onSeleccionarBiblioteca,
    required this.onCrearBiblioteca,
    required this.onEliminarBiblioteca,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    // El video de Búsqueda Online va por ENCIMA de todo, igual que en la
    // versión de celular. Antes este layout no lo montaba: en una tablet
    // (cualquier pantalla de 800px o más) se podía buscar en YouTube,
    // pero al tocar un resultado no pasaba absolutamente nada, porque
    // sin este widget el reproductor nunca llega a construirse.
    return Stack(
      children: [
        _construirLayout(context, player),
        const OnlineVideoOverlay(),
      ],
    );
  }

  Widget _construirLayout(BuildContext context, PlayerProvider player) {
    return Scaffold(
      body: Row(
        children: [
          BarraLateral(
            seccionActiva: seccionActiva,
            bibliotecaSeleccionada: bibliotecaSeleccionada,
            bibliotecas: bibliotecas,
            controladorNuevaBib: controladorNuevaBib,
            onCambiarSeccion: onCambiarSeccion,
            onSeleccionarBiblioteca: onSeleccionarBiblioteca,
            onCrearBiblioteca: onCrearBiblioteca,
            onEliminarBiblioteca: onEliminarBiblioteca,
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(child: contenidoPrincipal),
                const MiniPlayer(),
              ],
            ),
          ),
          Container(
            width: 300,
            color: AppTheme.background,
            padding: const EdgeInsets.all(16),
            child: player.currentSong == null
                ? const EstadoVacio(
                    icono: Icons.queue_music_rounded,
                    mensaje: 'Elegí una canción de la lista y acá vas a ver '
                        'la carátula, el álbum y los controles.',
                  )
                // Se desliza: es una ventana de escritorio y se puede
                // achicar a lo alto. Con la carátula de 260 más los dos
                // textos --y más todavía con la letra del sistema
                // agrandada-- una ventana baja dejaba este panel
                // desbordado. Deslizándose, eso es imposible.
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                player.currentSong!.album,
                                style: AppTheme.subheading,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Antes acá había un ícono de "más opciones"
                            // que era solo decorativo: no se podía tocar
                            // ni hacía nada. Ahora es el mismo menú real
                            // que usan todas las listas de la app.
                            SongOptionsMenu(
                              cancion: player.currentSong!,
                              bibliotecaSeleccionada: bibliotecaSeleccionada,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SongCover(
                          title: player.currentSong!.title,
                          artist: player.currentSong!.artist,
                          url: player.currentSong!.url,
                          coverUrlDirecto: player.currentSong!.coverUrl,
                          size: 260,
                          borderRadius: BorderRadius.circular(12),
                          showShadow: true,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          player.currentSong!.title,
                          style: AppTheme.heading.copyWith(fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          player.currentSong!.artist,
                          style: AppTheme.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Acá había una sección "Videos musicales
                        // relacionados" que nunca se implementó: era un
                        // recuadro vacío con un ícono de play que no
                        // llevaba a ninguna parte. Se sacó porque hacía
                        // ver la app a medio terminar; si algún día se
                        // arma de verdad, vuelve con contenido real.
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
