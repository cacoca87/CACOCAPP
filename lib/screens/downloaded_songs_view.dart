import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/boton_volver.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/song_cover.dart';
import '../widgets/song_options_menu.dart';

/// Lista todo lo que está descargado para escuchar offline, sin
/// importar de dónde vino originalmente (biblioteca del Drive/R2,
/// Jamendo, o una descarga vieja de YouTube). Se reproduce tocando,
/// igual que cualquier otra lista de la app, y cada canción tiene un
/// menú de opciones idéntico al del resto de la app.
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
  /// realmente hay que hacer (volver a Inicio). La explicación completa
  /// vive en `widgets/boton_volver.dart`.
  final VoidCallback? onVolver;

  const DownloadedSongsView({super.key, this.onVolver});

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
        leading: BotonVolver(onVolver: onVolver),
      ),
      body: descargadas.isEmpty
          ? const EstadoVacio(
              icono: Icons.download_done_rounded,
              mensaje:
                  "Todavía no descargaste ninguna canción. Tocá el ícono de "
                  "descarga en cualquier canción de tu biblioteca para "
                  "guardarla y escucharla sin conexión.",
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
                  // Mismo menú que en el resto de las listas. El que
                  // había acá era uno propio, y le faltaba justo la
                  // opción más importante de esta pantalla: no había
                  // forma de borrar una descarga desde "Música
                  // descargada".
                  trailing: SongOptionsMenu(
                    cancion: cancion,
                    // No es una playlist: ver la nota en `SongOptionsMenu`.
                    bibliotecaSeleccionada: null,
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
