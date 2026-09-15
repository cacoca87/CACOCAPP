import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/barra_lateral.dart';
import '../widgets/mini_player.dart';
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
                ? Center(
                    child: Text(
                      "Selecciona una canción",
                      style: AppTheme.body.copyWith(fontSize: 13),
                    ),
                  )
                : Column(
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
                          const Icon(Icons.more_horiz,
                              color: AppTheme.mutedInk),
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
                      const SizedBox(height: 24),
                      const Text(
                        "Videos musicales relacionados",
                        style: TextStyle(
                          color: AppTheme.paper,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 100,
                        decoration: AppTheme.cardDecoration,
                        child: const Center(
                          child: Icon(Icons.play_circle_filled,
                              size: 40, color: AppTheme.mutedInk),
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
