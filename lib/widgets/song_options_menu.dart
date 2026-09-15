import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../styles/app_theme.dart';

/// Menú (⋮) de "más opciones" para una canción: favoritos, descargar
/// offline, agregar/quitar de playlists. Extraído de
/// `pantalla_principal.dart` (donde vivía como `_construirMenuAcciones`
/// + `_mostrarDialogoNuevaPlaylist` + `_confirmarYDescargar`) para
/// bajar el tamaño de ese archivo -- es un widget autocontenido que
/// solo necesita la canción y el nombre de la biblioteca actual (para
/// saber si mostrar "Quitar de esta carpeta").
class SongOptionsMenu extends StatelessWidget {
  final Song cancion;
  final String bibliotecaSeleccionada;

  const SongOptionsMenu({
    super.key,
    required this.cancion,
    required this.bibliotecaSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final esFavorita = playlistProvider.isFavorite(cancion.id);
    final playerProvider = context.watch<PlayerProvider>();
    final estaDescargada = playerProvider.isDownloaded(cancion.id);

    Playlist? playlistActual;
    if (bibliotecaSeleccionada != "Principal (Drive)" &&
        bibliotecaSeleccionada != "Favoritos" &&
        bibliotecaSeleccionada != "Recientes") {
      for (final p in playlistProvider.playlists) {
        if (p.name == bibliotecaSeleccionada) {
          playlistActual = p;
          break;
        }
      }
    }
    final yaEnPlaylistActual = playlistActual != null &&
        playlistActual.songs.any((s) => s.id == cancion.id);

    return PopupMenuButton<String>(
      tooltip: "Más opciones",
      icon: const Icon(Icons.more_vert, color: AppTheme.mutedInk),
      color: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (accion) {
        final provider = context.read<PlaylistProvider>();
        if (accion == "favoritos") {
          HapticFeedback.mediumImpact();
          provider.toggleFavorite(cancion.id);
        } else if (accion == "quitar_actual" && playlistActual != null) {
          provider.removeSongFromPlaylist(playlistActual.id, cancion.id);
        } else if (accion == "nueva_playlist") {
          mostrarDialogoNuevaPlaylist(context, cancion);
        } else if (accion.startsWith("add_")) {
          provider.addSongToPlaylist(accion.substring(4), cancion);
        } else if (accion == "descargar") {
          confirmarYDescargar(context, cancion);
        } else if (accion == "eliminar_descarga") {
          context.read<PlayerProvider>().deleteDownload(cancion.id);
        }
      },
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = [
          PopupMenuItem(
            value: "favoritos",
            child: Row(
              children: [
                Icon(
                  esFavorita ? Icons.favorite : Icons.favorite_border,
                  color: AppTheme.danger,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  esFavorita ? "Quitar de Favoritos" : "Añadir a Favoritos",
                  style: AppTheme.body
                      .copyWith(color: AppTheme.paper, fontSize: 13),
                ),
              ],
            ),
          ),
          if (estaDescargada)
            PopupMenuItem(
              value: "eliminar_descarga",
              child: Row(
                children: [
                  const Icon(Icons.delete_outline,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: 10),
                  Text("Eliminar descarga",
                      style: AppTheme.body
                          .copyWith(color: AppTheme.danger, fontSize: 13)),
                ],
              ),
            )
          else
            PopupMenuItem(
              value: "descargar",
              child: Row(
                children: [
                  const Icon(Icons.download, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Text("Descargar offline",
                      style: AppTheme.body
                          .copyWith(color: AppTheme.paper, fontSize: 13)),
                ],
              ),
            ),
        ];
        if (yaEnPlaylistActual) {
          items.add(
            PopupMenuItem(
              value: "quitar_actual",
              child: Row(
                children: [
                  const Icon(Icons.remove_circle_outline,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: 10),
                  Text("Quitar de esta carpeta",
                      style: AppTheme.body
                          .copyWith(color: AppTheme.danger, fontSize: 13)),
                ],
              ),
            ),
          );
        }
        items.add(const PopupMenuDivider());
        for (final p in playlistProvider.playlists) {
          items.add(
            PopupMenuItem(
              value: "add_${p.id}",
              child: Row(
                children: [
                  const Icon(Icons.folder, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Text(p.name,
                      style: AppTheme.body
                          .copyWith(color: AppTheme.paper, fontSize: 13)),
                ],
              ),
            ),
          );
        }
        items.add(
          PopupMenuItem(
            value: "nueva_playlist",
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Text("Nueva playlist...",
                    style: AppTheme.body
                        .copyWith(color: AppTheme.paper, fontSize: 13)),
              ],
            ),
          ),
        );
        return items;
      },
    );
  }
}

Future<void> mostrarDialogoNuevaPlaylist(
    BuildContext context, Song cancion) async {
  final controlador = TextEditingController();
  final nombre = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text("Nueva playlist",
          style: AppTheme.subheading.copyWith(fontSize: 17)),
      content: TextField(
        controller: controlador,
        autofocus: true,
        style: AppTheme.body.copyWith(color: AppTheme.paper),
        decoration: InputDecoration(
          hintText: "Nombre de la playlist",
          hintStyle: AppTheme.body.copyWith(color: AppTheme.faintInk),
          filled: true,
          fillColor: AppTheme.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text("Cancelar",
              style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(dialogContext, controlador.text.trim()),
          style: AppTheme.primaryButton,
          child: const Text("Crear"),
        ),
      ],
    ),
  );
  // El diálogo ya se cerró acá, así que el controlador no lo usa nadie
  // más. Sin esto quedaba vivo para siempre: al vivir en una función
  // suelta (no en un State) no hay ningún `dispose()` que lo libere, y
  // se acumulaba uno nuevo cada vez que se abría el diálogo.
  controlador.dispose();

  if (nombre == null || nombre.isEmpty) return;
  if (!context.mounted) return;

  final provider = context.read<PlaylistProvider>();
  final yaExiste = provider.playlists.any((p) => p.name == nombre);
  final playlist = yaExiste
      ? provider.playlists.firstWhere((p) => p.name == nombre)
      : provider.createPlaylist(nombre);

  provider.addSongToPlaylist(playlist.id, cancion);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Agregada a "$nombre"'),
      backgroundColor: AppTheme.primary,
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> confirmarYDescargar(BuildContext context, Song cancion) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.surfaceLight,
      title: Text('Descargar canción',
          style: AppTheme.subheading.copyWith(fontSize: 17)),
      content: Text(
        'Se descargará "${cancion.title}" para escucharla sin conexión. '
        'Esto puede consumir datos móviles si no estás en Wi-Fi.',
        style: AppTheme.body.copyWith(color: AppTheme.mutedInk),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancelar',
              style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Descargar',
              style: TextStyle(color: AppTheme.primary)),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;

  final provider = context.read<PlayerProvider>();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Descargando "${cancion.title}"...'),
      backgroundColor: AppTheme.primary,
      duration: const Duration(seconds: 2),
    ),
  );

  final exito = await provider.downloadSong(cancion);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        exito
            ? '"${cancion.title}" descargada ✓'
            : 'No se pudo descargar "${cancion.title}". Revisa tu conexión.',
      ),
      backgroundColor: exito ? AppTheme.amber : AppTheme.danger,
      duration: const Duration(seconds: 3),
    ),
  );
}
