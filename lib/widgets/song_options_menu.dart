import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../styles/app_theme.dart';
import '../utils/bibliotecas_reservadas.dart';

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
    // Los cuatro nombres reservados vienen de un solo lugar: antes acá
    // faltaba "Más Escuchadas".
    if (!nombresReservadosDeBiblioteca.contains(bibliotecaSeleccionada)) {
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
          final id = accion.substring(4);
          provider.addSongToPlaylist(id, cancion);
          // Antes esto no avisaba NADA: tocabas una playlist, el menú
          // se cerraba y no pasaba nada visible. La canción sí se
          // agregaba, pero no había forma de saberlo sin ir a mirar.
          // Las otras dos formas de agregar --"Nueva playlist" y
          // Favoritos-- sí avisaban, así que esta era la rara.
          _avisar(context, 'Agregada a "${_nombreDePlaylist(provider, id)}"');
        } else if (accion == "descargar") {
          confirmarYDescargar(context, cancion);
        } else if (accion == "eliminar_descarga") {
          confirmarYEliminarDescarga(context, cancion);
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
          // Una canción que ya vive en el celular no se descarga ni se
          // "elimina la descarga": las dos opciones sobran, y la de
          // descargar además fallaba siempre con "revisá tu conexión",
          // porque descargar es bajar algo de internet y esta no está
          // en internet. Para borrarla de verdad está el administrador
          // de archivos del teléfono, que es donde corresponde.
          if (cancion.estaEnElCelular)
            const PopupMenuItem<String>(
              enabled: false,
              child: Row(
                children: [
                  Icon(Icons.smartphone_rounded,
                      color: AppTheme.mutedInk, size: 18),
                  SizedBox(width: 10),
                  Text('Ya está en tu celular',
                      style: TextStyle(color: AppTheme.mutedInk, fontSize: 13)),
                ],
              ),
            )
          else if (estaDescargada)
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
          // Antes todas las playlists se veían igual, estuviera la
          // canción adentro o no. Tocar una que ya la tenía no hacía
          // nada --el modelo no permite repetidas-- y no había forma de
          // notar la diferencia: parecía que el menú no funcionaba.
          final yaLaTiene = p.songs.any((s) => s.id == cancion.id);
          items.add(
            PopupMenuItem(
              value: "add_${p.id}",
              enabled: !yaLaTiene,
              child: Row(
                children: [
                  Icon(yaLaTiene ? Icons.check_rounded : Icons.folder,
                      color: yaLaTiene ? AppTheme.mutedInk : AppTheme.primary,
                      size: 18),
                  const SizedBox(width: 10),
                  // El nombre lo escribe la persona y puede ser largo:
                  // sin acotarlo, se desbordaba del ancho del menú.
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body.copyWith(
                            color:
                                yaLaTiene ? AppTheme.mutedInk : AppTheme.paper,
                            fontSize: 13)),
                  ),
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

  if (nombre == null) return;
  if (!context.mounted) return;

  final provider = context.read<PlaylistProvider>();

  // Este era el tercer lugar donde se crean playlists, y el unico que
  // no validaba nada: desde aca se podia crear una llamada "Favoritos"
  // o "Recientes" y esquivar las reglas de la barra lateral. Un nombre
  // repetido SI vale: en ese caso se agrega a la que ya existe, que es
  // lo que la persona esta pidiendo.
  final yaExiste = provider.playlists.any((p) => p.name == nombre);
  if (!yaExiste) {
    final error = errorDeNombreDeBiblioteca(
      nombre,
      nombresExistentes: const [],
    );
    if (error != null) {
      if (nombre.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), duration: const Duration(seconds: 3)),
        );
      }
      return;
    }
  }

  final playlist = yaExiste
      ? provider.playlists.firstWhere((p) => p.name == nombre)
      : provider.createPlaylist(nombre);

  provider.addSongToPlaylist(playlist.id, cancion);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Agregada a "$nombre"', style: AppTheme.textoSobreAmbar),
      backgroundColor: AppTheme.primary,
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> confirmarYDescargar(BuildContext context, Song cancion) async {
  final provider = context.read<PlayerProvider>();

  // `downloadSong` devuelve `false` tanto si falló como si esa canción
  // ya se está bajando. Sin esta comprobación, tocar descargar dos veces
  // mostraba "No se pudo descargar, revisá tu conexión" mientras la
  // descarga andaba perfecto.
  if (provider.isDownloading(cancion.id)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${cancion.title}" ya se está descargando.'),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }

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

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Descargando "${cancion.title}"...',
          style: AppTheme.textoSobreAmbar),
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
        // Crema sobre ambar no se lee al sol: sobre ambar el texto va
        // oscuro. Ver `AppTheme.textoSobreAmbar`.
        style: exito ? AppTheme.textoSobreAmbar : null,
      ),
      backgroundColor: exito ? AppTheme.amber : AppTheme.danger,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Borra el archivo descargado, previa confirmacion.
///
/// La confirmacion hace falta porque es la unica accion destructiva de
/// la app sin vuelta atras: el archivo se borra del telefono y hay que
/// volver a bajarlo con datos. "Descargar offline", que gasta menos,
/// ya preguntaba; esta no.
Future<void> confirmarYEliminarDescarga(
    BuildContext context, Song cancion) async {
  final provider = context.read<PlayerProvider>();

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.surfaceLight,
      title: Text('¿Eliminar la descarga?',
          style: AppTheme.subheading.copyWith(fontSize: 17)),
      content: Text(
        'Se borra el archivo de "${cancion.title}" del celular. La canción '
        'sigue en tu biblioteca, pero para escucharla sin conexión vas a '
        'tener que descargarla de nuevo.',
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
          child:
              const Text('Eliminar', style: TextStyle(color: AppTheme.danger)),
        ),
      ],
    ),
  );
  if (confirmar != true) return;

  await provider.deleteDownload(cancion.id);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Se eliminó la descarga de "${cancion.title}"'),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// El nombre de una playlist por su id, o un texto neutro si ya no
/// existe (puede haberse borrado desde otra pantalla mientras el menú
/// estaba abierto).
String _nombreDePlaylist(PlaylistProvider provider, String id) {
  for (final p in provider.playlists) {
    if (p.id == id) return p.name;
  }
  return 'la playlist';
}

void _avisar(BuildContext context, String mensaje) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje, style: AppTheme.textoSobreAmbar),
      backgroundColor: AppTheme.primary,
      duration: const Duration(seconds: 2),
    ),
  );
}
