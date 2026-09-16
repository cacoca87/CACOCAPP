import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import 'carrusel_canciones.dart';
import 'carrusel_playlists.dart';

/// Pestaña de "Inicio" (recientes, más escuchadas, playlists,
/// favoritas, recomendaciones). Extraído de `pantalla_principal.dart`
/// (donde vivía como `_construirInicio`).
///
/// Único cambio de comportamiento respecto al original: en vez de
/// hacer `setState` directo sobre el estado de `PantallaPrincipal`,
/// cada acción de navegación (tocar "Toda tu música", "Ver todo" de
/// cada carrusel, tocar una playlist puntual) se expone como
/// callback. Quien instancia este widget decide qué hacer con cada
/// una -- en `pantalla_principal.dart` simplemente hacen el mismo
/// `setState` que antes vivía acá adentro.
class InicioTab extends StatelessWidget {
  final PlayerProvider player;
  final bool esPantallaPequena;
  final int totalCanciones;
  final List<Song> recientes;
  final List<Song> masEscuchadas;
  final List<Song> favoritos;
  final List<Song> recomendaciones;
  final List<Playlist> playlists;
  final Future<void> Function() onRefrescar;
  final VoidCallback onVerBibliotecaCompleta;
  final VoidCallback onAbrirBuscadorOnline;
  final VoidCallback onVerTodoRecientes;
  final VoidCallback onVerTodoMasEscuchadas;
  final VoidCallback onVerTodoPlaylists;
  final VoidCallback onVerTodoFavoritos;
  final VoidCallback onVerTodoRecomendaciones;
  final ValueChanged<String> onSeleccionarPlaylist;
  final ValueChanged<String> onIrASeccion;

  const InicioTab({
    super.key,
    required this.player,
    required this.esPantallaPequena,
    required this.totalCanciones,
    required this.recientes,
    required this.masEscuchadas,
    required this.favoritos,
    required this.recomendaciones,
    required this.playlists,
    required this.onRefrescar,
    required this.onVerBibliotecaCompleta,
    required this.onAbrirBuscadorOnline,
    required this.onVerTodoRecientes,
    required this.onVerTodoMasEscuchadas,
    required this.onVerTodoPlaylists,
    required this.onVerTodoFavoritos,
    required this.onVerTodoRecomendaciones,
    required this.onSeleccionarPlaylist,
    required this.onIrASeccion,
  });

  @override
  Widget build(BuildContext context) {
    final hayContenidoPersonalizado = recientes.isNotEmpty ||
        masEscuchadas.isNotEmpty ||
        favoritos.isNotEmpty ||
        recomendaciones.isNotEmpty ||
        playlists.isNotEmpty;

    return RefreshIndicator(
      onRefresh: onRefrescar,
      color: AppTheme.amber,
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Acceso directo a la biblioteca completa
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onVerBibliotecaCompleta,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.library_music_rounded,
                        color: AppTheme.ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Toda tu música",
                          style: AppTheme.body.copyWith(
                              color: AppTheme.paper,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text("$totalCanciones canciones en tu biblioteca",
                            style: AppTheme.small),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.mutedInk),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ACCESO DIRECTO AL BUSCADOR ONLINE DE YOUTUBE
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: InkWell(
              onTap: onAbrirBuscadorOnline,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.video_library_rounded,
                          color: AppTheme.amber),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Buscador Online",
                            style: AppTheme.body.copyWith(
                                color: AppTheme.paper,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text("Busca y mira videos de YouTube en la app",
                              style: AppTheme.small),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.amber),
                  ],
                ),
              ),
            ),
          ),
          if (!hayContenidoPersonalizado)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 48, color: AppTheme.mutedInk),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        "Empieza a escuchar música para que aparezcan aquí tus recientes, favoritas y recomendaciones.",
                        style: AppTheme.body.copyWith(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (recientes.isNotEmpty)
            CarruselCanciones(
              titulo: "Escuchado recientemente",
              canciones: recientes,
              player: player,
              esPantallaPequena: esPantallaPequena,
              onVerTodo: onVerTodoRecientes,
            ),
          if (masEscuchadas.isNotEmpty)
            CarruselCanciones(
              titulo: "Tus más escuchadas",
              canciones: masEscuchadas,
              player: player,
              esPantallaPequena: esPantallaPequena,
              onVerTodo: onVerTodoMasEscuchadas,
            ),
          if (playlists.isNotEmpty)
            CarruselPlaylists(
              titulo: "Tus playlists",
              playlists: playlists,
              esPantallaPequena: esPantallaPequena,
              onVerTodo: onVerTodoPlaylists,
              onSeleccionarPlaylist: onSeleccionarPlaylist,
            ),
          if (favoritos.isNotEmpty)
            CarruselCanciones(
              titulo: "Tus favoritas",
              canciones: favoritos,
              player: player,
              esPantallaPequena: esPantallaPequena,
              onVerTodo: onVerTodoFavoritos,
            ),
          if (recomendaciones.isNotEmpty)
            CarruselCanciones(
              titulo: "Recomendado para ti",
              canciones: recomendaciones,
              player: player,
              esPantallaPequena: esPantallaPequena,
              onVerTodo: onVerTodoRecomendaciones,
            ),
          const SizedBox(height: 20),

          // Accesos rápidos a todo lo que antes solo vivía en el menú
          // lateral (Playlists, Artistas, Álbumes, Música Descargada,
          // Estadísticas, Recomendaciones, Descubrir) -- sin esto, esas
          // secciones no tenían ninguna presencia visual en Inicio y
          // solo se llegaba a ellas abriendo el drawer.
          //
          // Va DEBAJO de los carruseles a propósito. Antes estaba
          // arriba de todo, y había que pasar una pantalla entera de
          // recuadros grises antes de ver una sola tapa de disco --
          // siendo que las carátulas son lo más lindo que tiene la app.
          // Primero el contenido, después la navegación.
          Text("Explorar",
              style: AppTheme.heading
                  .copyWith(fontSize: esPantallaPequena ? 16 : 18)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: esPantallaPequena ? 3 : 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              _AccesoRapido(
                icono: Icons.queue_music_rounded,
                etiqueta: "Playlists",
                onTap: onVerTodoPlaylists,
              ),
              _AccesoRapido(
                icono: Icons.person_rounded,
                etiqueta: "Artistas",
                onTap: () => onIrASeccion("Artistas"),
              ),
              _AccesoRapido(
                icono: Icons.album_rounded,
                etiqueta: "Álbumes",
                onTap: () => onIrASeccion("Álbumes"),
              ),
              _AccesoRapido(
                icono: Icons.download_done_rounded,
                etiqueta: "Descargada",
                onTap: () => onIrASeccion("Música Descargada"),
              ),
              _AccesoRapido(
                icono: Icons.auto_awesome_rounded,
                etiqueta: "Recomendado",
                onTap: onVerTodoRecomendaciones,
              ),
              _AccesoRapido(
                icono: Icons.travel_explore_rounded,
                etiqueta: "Descubrir",
                onTap: () => onIrASeccion("Descubrir"),
              ),
              _AccesoRapido(
                icono: Icons.bar_chart_rounded,
                etiqueta: "Estadísticas",
                onTap: () => onIrASeccion("Estadísticas"),
              ),
              _AccesoRapido(
                icono: Icons.videogame_asset_rounded,
                etiqueta: "Juegos",
                onTap: () => onIrASeccion("Juegos"),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AccesoRapido extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  const _AccesoRapido({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: AppTheme.amber, size: 24),
            const SizedBox(height: 8),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTheme.small.copyWith(color: AppTheme.paper, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
