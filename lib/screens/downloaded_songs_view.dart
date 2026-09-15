import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/song_cover.dart';
import '../widgets/song_options_menu.dart';

/// Lista todo lo que está descargado para escuchar offline, sin
/// importar de dónde vino originalmente (biblioteca del Drive/R2,
/// Jamendo, o una descarga vieja de YouTube). Se reproduce tocando,
/// igual que cualquier otra lista de la app, y cada canción tiene un
/// menú para mandarla a favoritos o a una playlist.
///
/// Recreada después de que se sacó por error en una vuelta anterior --
/// en ese momento parecía que "descargado" solo se refería a las
/// descargas rotas de Búsqueda Online (YouTube), pero las descargas de
/// la biblioteca principal (R2/Drive) siempre funcionaron bien y se
/// quedaron sin ningún lugar donde verse.
class DownloadedSongsView extends StatelessWidget {
  /// Esta pantalla se inserta directo dentro de PantallaPrincipal (no
  /// se abre con Navigator.push), así que el botón "volver" no puede
  /// usar Navigator.pop -- no hay ninguna ruta apilada que sacar. En su
  /// lugar, quien construye esta pantalla pasa [onVolver] con lo que
  /// realmente hay que hacer (volver a Inicio).
  final VoidCallback? onVolver;

  const DownloadedSongsView({super.key, this.onVolver});

  void _volver(BuildContext context) {
    if (onVolver != null) {
      onVolver!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _mostrarMenu(BuildContext context, Song cancion) {
    final playlistProvider = context.read<PlaylistProvider>();
    final esFavorita = playlistProvider.isFavorite(cancion.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  esFavorita
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: esFavorita ? AppTheme.amber : AppTheme.mutedInk,
                ),
                title: Text(
                  esFavorita ? "Quitar de favoritos" : "Agregar a favoritos",
                  style: AppTheme.body.copyWith(color: AppTheme.paper),
                ),
                onTap: () {
                  playlistProvider.toggleFavorite(cancion.id);
                  Navigator.pop(sheetContext);
                },
              ),
              if (playlistProvider.playlists.isNotEmpty)
                const Divider(color: AppTheme.hairline, height: 1),
              for (final playlist in playlistProvider.playlists)
                ListTile(
                  leading:
                      const Icon(Icons.folder_rounded, color: AppTheme.primary),
                  title: Text(playlist.name,
                      style: AppTheme.body.copyWith(color: AppTheme.paper)),
                  onTap: () {
                    playlistProvider.addSongToPlaylist(playlist.id, cancion);
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Se agregó "${cancion.title}" a "${playlist.name}"')),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded,
                    color: AppTheme.primary),
                title: Text("Nueva playlist...",
                    style: AppTheme.body.copyWith(color: AppTheme.paper)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  mostrarDialogoNuevaPlaylist(context, cancion);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final descargadas = player.downloadedSongs;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title: Text('Música descargada',
            style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.paper),
          tooltip: "Volver",
          onPressed: () => _volver(context),
        ),
      ),
      body: descargadas.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_done_rounded,
                        size: 48, color: AppTheme.mutedInk),
                    const SizedBox(height: 12),
                    Text(
                      "Todavía no descargaste ninguna canción. Tocá el ícono de "
                      "descarga en cualquier canción de tu biblioteca para guardarla "
                      "offline.",
                      style: AppTheme.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: descargadas.length,
              itemBuilder: (context, index) {
                final cancion = descargadas[index];
                final sonandoAhora = player.currentSong?.id == cancion.id;
                return ListTile(
                  leading: SongCover(
                    title: cancion.title,
                    artist: cancion.artist,
                    url: cancion.url,
                    coverUrlDirecto: cancion.coverUrl,
                    size: 44,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  title: Text(
                    cancion.title,
                    style: AppTheme.body.copyWith(
                      color: sonandoAhora ? AppTheme.amber : AppTheme.paper,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    cancion.artist,
                    style: AppTheme.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppTheme.mutedInk),
                    tooltip: "Opciones",
                    onPressed: () => _mostrarMenu(context, cancion),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    player.playSong(cancion, descargadas, index);
                  },
                );
              },
            ),
    );
  }
}
