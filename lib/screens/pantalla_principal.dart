import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/online_video_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/drive_service.dart';
import '../services/id3_cover_service.dart';
import '../styles/app_theme.dart';
import '../widgets/barra_lateral.dart';
import '../widgets/inicio_tab.dart';
import '../widgets/indicador_sonando.dart';
import '../widgets/mini_player.dart';
import '../widgets/online_video_overlay.dart';
import '../widgets/song_cover.dart';
import '../widgets/vista_spotify_grid.dart';
import 'statistics_screen.dart';
import 'recommendations_screen.dart';
import 'descubrir_screen.dart';
import 'downloaded_songs_view.dart';
import 'dual_search_screen.dart'; // <--- IMPORTACIÓN DE TU BUSCADOR ONLINE

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final DriveService _driveService = DriveService();
  final TextEditingController _buscadorController = TextEditingController();
  final TextEditingController _nuevaBibController = TextEditingController();

  List<Song> canciones = [];
  bool cargando = true;
  bool actualizando = false;

  String seccionActiva = "Tu Biblioteca";
  String bibliotecaSeleccionada = "Principal (Drive)";
  String? subFiltroSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarCanciones();
    _buscadorController.addListener(() => setState(() {}));
  }

  Future<void> _cargarCanciones() async {
    final list = await _driveService.obtenerCanciones();
    setState(() {
      canciones = list;
      cargando = false;
    });
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    await player.restoreSession(list);
    if (!mounted) return;
    // Esperamos a que las descargas (que pueden incluir canciones de
    // Jamendo/buscador online que NO están en `list`) terminen de leerse
    // de disco, para que una canción descargada agregada a una playlist
    // no "desaparezca" de esa playlist al reabrir la app.
    await player.whenDownloadsLoaded;
    if (!mounted) return;
    await context
        .read<PlaylistProvider>()
        .loadFromPrefs([...list, ...player.downloadedSongs]);
    _resolverAlbumesReales(list);
  }

  Future<void> _actualizarCanciones() async {
    setState(() => actualizando = true);
    try {
      final list = await _driveService.refrescarCanciones();
      if (!mounted) return;
      setState(() {
        canciones = list;
        actualizando = false;
      });
      final player = context.read<PlayerProvider>();
      await player.whenDownloadsLoaded;
      if (!mounted) return;
      await context
          .read<PlaylistProvider>()
          .loadFromPrefs([...list, ...player.downloadedSongs]);
      _resolverAlbumesReales(list);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Biblioteca actualizada: ${list.length} canciones"),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => actualizando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("No se pudo actualizar. Revisa tu conexión."),
          backgroundColor: AppTheme.danger,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resolverAlbumesReales(List<Song> lista) async {
    const concurrencia = 6;
    var huboCambios = false;

    for (var i = 0; i < lista.length; i += concurrencia) {
      if (!mounted) return;
      final lote = lista.skip(i).take(concurrencia);
      await Future.wait(lote.map((cancion) async {
        final album = await Id3CoverService.instance.getEmbeddedAlbum(cancion.url);
        if (album != null && album.isNotEmpty && album != cancion.album) {
          cancion.album = album;
          huboCambios = true;
        }
      }));
    }

    if (mounted && huboCambios) setState(() {});
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    _nuevaBibController.dispose();
    super.dispose();
  }

  String _mensajeBibliotecaVacia() {
    if (bibliotecaSeleccionada == "Favoritos") {
      return "Todavía no tienes canciones favoritas.\nToca el corazón en cualquier canción para agregarla aquí.";
    }
    if (bibliotecaSeleccionada == "Recientes") {
      return "Todavía no has reproducido ninguna canción.\nAparecerán aquí en cuanto empieces a escuchar.";
    }
    if (bibliotecaSeleccionada == "Más Escuchadas") {
      return "Todavía no hay suficiente historial.\nEntre más escuches, más precisa será esta lista.";
    }
    if (bibliotecaSeleccionada == "Principal (Drive)") {
      return "No se encontraron canciones. Prueba actualizar con el botón de arriba.";
    }
    return 'La playlist "$bibliotecaSeleccionada" está vacía.\nAgrégale canciones desde el menú (⋮) de cualquier canción.';
  }

  void _crearBiblioteca() {
    final nombre = _nuevaBibController.text.trim();
    if (nombre.isEmpty) return;
    if (nombre == "Principal (Drive)" || nombre == "Favoritos") return;

    final provider = context.read<PlaylistProvider>();
    final yaExiste = provider.playlists.any((p) => p.name == nombre);
    if (yaExiste) return;

    provider.createPlaylist(nombre);
    setState(() {
      bibliotecaSeleccionada = nombre;
      seccionActiva = "Tu Biblioteca";
      _nuevaBibController.clear();
    });
  }

  Future<void> _mostrarMenuBiblioteca(String nombre) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.paper),
              title: Text("Renombrar", style: AppTheme.body.copyWith(color: AppTheme.paper)),
              onTap: () => Navigator.pop(context, "renombrar"),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: Text("Eliminar", style: AppTheme.body.copyWith(color: AppTheme.danger)),
              onTap: () => Navigator.pop(context, "eliminar"),
            ),
          ],
        ),
      ),
    );

    if (!mounted || accion == null) return;
    if (accion == "renombrar") {
      await _renombrarBiblioteca(nombre);
    } else if (accion == "eliminar") {
      await _confirmarEliminarBiblioteca(nombre);
    }
  }

  Future<void> _renombrarBiblioteca(String nombreActual) async {
    final playlistProvider = context.read<PlaylistProvider>();
    Playlist? playlist;
    for (final p in playlistProvider.playlists) {
      if (p.name == nombreActual) {
        playlist = p;
        break;
      }
    }
    if (playlist == null) return;
    final playlistARenombrar = playlist;

    final controlador = TextEditingController(text: nombreActual);
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Renombrar playlist", style: AppTheme.subheading.copyWith(fontSize: 17)),
        content: TextField(
          controller: controlador,
          autofocus: true,
          style: AppTheme.body.copyWith(color: AppTheme.paper),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controlador.text.trim()),
            style: AppTheme.primaryButton,
            child: const Text("Guardar"),
          ),
        ],
      ),
    );

    if (nuevoNombre == null || nuevoNombre.isEmpty || nuevoNombre == nombreActual) return;
    if (!mounted) return;

    playlistProvider.renamePlaylist(playlistARenombrar.id, nuevoNombre);
    setState(() {
      if (bibliotecaSeleccionada == nombreActual) bibliotecaSeleccionada = nuevoNombre;
      if (subFiltroSeleccionado == nombreActual) subFiltroSeleccionado = nuevoNombre;
    });
  }

  Future<void> _confirmarEliminarBiblioteca(String nombre) async {
    final playlistProvider = context.read<PlaylistProvider>();
    Playlist? playlist;
    for (final p in playlistProvider.playlists) {
      if (p.name == nombre) {
        playlist = p;
        break;
      }
    }
    if (playlist == null) return;
    final playlistAEliminar = playlist;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("¿Eliminar playlist?", style: AppTheme.subheading.copyWith(fontSize: 17)),
        content: Text(
          'Se eliminará "$nombre" con sus ${playlistAEliminar.songs.length} canciones. Las canciones en sí no se borran, solo esta playlist.',
          style: AppTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar", style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: AppTheme.paper,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!mounted) return;

    playlistProvider.deletePlaylist(playlistAEliminar.id);
    setState(() {
      if (bibliotecaSeleccionada == nombre) {
        bibliotecaSeleccionada = "Principal (Drive)";
      }
      if (subFiltroSeleccionado == nombre) {
        subFiltroSeleccionado = null;
      }
    });
  }

  Future<void> _confirmarYDescargar(Song cancion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text('Descargar canción', style: AppTheme.subheading.copyWith(fontSize: 17)),
        content: Text(
          'Se descargará "${cancion.title}" para escucharla sin conexión. '
          'Esto puede consumir datos móviles si no estás en Wi-Fi.',
          style: AppTheme.body.copyWith(color: AppTheme.mutedInk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descargar', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final provider = context.read<PlayerProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando "${cancion.title}"...'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    final exito = await provider.downloadSong(cancion);
    if (!mounted) return;

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

  void _volverAInicio() {
    setState(() {
      seccionActiva = "Tu Biblioteca";
      bibliotecaSeleccionada = "Principal (Drive)";
      subFiltroSeleccionado = null;
    });
  }

  /// Misma lógica que ya usaba `BarraLateral.onCambiarSeccion` (ver más
  /// abajo, en el `build`) -- factorizada acá para que los accesos
  /// rápidos de `InicioTab` puedan saltar a cualquier sección sin
  /// duplicar el `setState` una tercera vez.
  void _cambiarSeccion(String seccion) {
    setState(() {
      seccionActiva = seccion;
      subFiltroSeleccionado = null;
      if (seccion == "Tu Biblioteca") bibliotecaSeleccionada = "Principal (Drive)";
    });
  }

  Widget _construirMenuAcciones(Song cancion) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final esFavorita = playlistProvider.isFavorite(cancion.id);
    final playerProviderDescargas = context.watch<PlayerProvider>();
    final estaDescargada = playerProviderDescargas.isDownloaded(cancion.id);

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
          _mostrarDialogoNuevaPlaylist(cancion);
        } else if (accion.startsWith("add_")) {
          provider.addSongToPlaylist(accion.substring(4), cancion);
        } else if (accion == "descargar") {
          _confirmarYDescargar(cancion);
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
                  style: AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 13),
                ),
              ],
            ),
          ),
          if (estaDescargada)
            PopupMenuItem(
              value: "eliminar_descarga",
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                  const SizedBox(width: 10),
                  Text("Eliminar descarga", style: AppTheme.body.copyWith(color: AppTheme.danger, fontSize: 13)),
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
                  Text("Descargar offline", style: AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 13)),
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
                  const Icon(Icons.remove_circle_outline, color: AppTheme.danger, size: 18),
                  const SizedBox(width: 10),
                  Text("Quitar de esta carpeta", style: AppTheme.body.copyWith(color: AppTheme.danger, fontSize: 13)),
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
                  Text(p.name, style: AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 13)),
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
                const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Text("Nueva playlist...", style: AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 13)),
              ],
            ),
          ),
        );
        return items;
      },
    );
  }

  Future<void> _mostrarDialogoNuevaPlaylist(Song cancion) async {
    final controlador = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Nueva playlist", style: AppTheme.subheading.copyWith(fontSize: 17)),
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
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controlador.text.trim()),
            style: AppTheme.primaryButton,
            child: const Text("Crear"),
          ),
        ],
      ),
    );

    if (nombre == null || nombre.isEmpty) return;
    if (!mounted) return;

    final provider = context.read<PlaylistProvider>();
    final yaExiste = provider.playlists.any((p) => p.name == nombre);
    final playlist = yaExiste
        ? provider.playlists.firstWhere((p) => p.name == nombre)
        : provider.createPlaylist(nombre);

    provider.addSongToPlaylist(playlist.id, cancion);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Agregada a "$nombre"'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final onlineVideo = context.watch<OnlineVideoProvider>();
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esPantallaPequena = anchoPantalla < 800;

    final List<String> nombresBibliotecas = [
      "Principal (Drive)",
      "Favoritos",
      "Recientes",
      "Más Escuchadas",
      ...playlistProvider.playlists.map((p) => p.name),
    ];

    List<Song> cancionesParaNombre(String nombre) {
      if (nombre == "Principal (Drive)") return canciones;
      if (nombre == "Favoritos") {
        return canciones.where((c) => playlistProvider.isFavorite(c.id)).toList();
      }
      if (nombre == "Recientes") {
        final porId = {for (final c in canciones) c.id: c};
        return player.historialIds.map((id) => porId[id]).whereType<Song>().toList();
      }
      if (nombre == "Más Escuchadas") {
        final porId = {for (final c in canciones) c.id: c};
        return player.masEscuchadasIds.map((id) => porId[id]).whereType<Song>().toList();
      }
      for (final p in playlistProvider.playlists) {
        if (p.name == nombre) return p.songs;
      }
      return [];
    }

    List<String> listaArtistas = canciones.map((c) => c.artist).toSet().toList();
    List<String> listaAlbumes = canciones.map((c) => c.album).toSet().toList();

    final Map<String, Song> representativaPorArtista = {};
    final Map<String, Song> representativaPorAlbum = {};
    for (final c in canciones) {
      representativaPorArtista.putIfAbsent(c.artist, () => c);
      representativaPorAlbum.putIfAbsent(c.album, () => c);
    }

    Widget widgetCentral;
    if (seccionActiva == "Estadísticas") {
      widgetCentral = StatisticsScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == "Recomendaciones") {
      widgetCentral = RecommendationsScreen(allSongs: canciones, onVolver: _volverAInicio);
    } else if (seccionActiva == "Descubrir") {
      widgetCentral = DescubrirScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == "Buscador Online") {
      widgetCentral = DualSearchScreen(onVolver: _volverAInicio); // <--- PASANDO LA FUNCIÓN DE RETORNO
    } else if (seccionActiva == "Música Descargada") {
      widgetCentral = DownloadedSongsView(onVolver: _volverAInicio);
    } else {
      final mostrarInicio = seccionActiva == "Tu Biblioteca" &&
          bibliotecaSeleccionada == "Principal (Drive)" &&
          subFiltroSeleccionado == null;

      List<Song> cancionesBase = [];
      if (seccionActiva == "Tu Biblioteca" && !mostrarInicio) {
        if (bibliotecaSeleccionada == "Principal (Drive)") {
          cancionesBase = cancionesParaNombre(subFiltroSeleccionado!);
        } else {
          cancionesBase = cancionesParaNombre(bibliotecaSeleccionada);
        }
      } else if (seccionActiva == "Artistas" && subFiltroSeleccionado != null) {
        cancionesBase = canciones.where((c) => c.artist == subFiltroSeleccionado).toList();
      } else if (seccionActiva == "Álbumes" && subFiltroSeleccionado != null) {
        cancionesBase = canciones.where((c) => c.album == subFiltroSeleccionado).toList();
      } else if (seccionActiva == "Playlists" && subFiltroSeleccionado != null) {
        cancionesBase = cancionesParaNombre(subFiltroSeleccionado!);
      }

      final nombreVistaActual = (seccionActiva == "Tu Biblioteca" && !mostrarInicio)
          ? (bibliotecaSeleccionada == "Principal (Drive)" ? subFiltroSeleccionado : bibliotecaSeleccionada)
          : (seccionActiva == "Playlists" ? subFiltroSeleccionado : null);
      final esVistaDeFavoritos = nombreVistaActual == "Favoritos";
      Playlist? playlistDeVistaActual;
      if (nombreVistaActual != null &&
          nombreVistaActual != "Principal (Drive)" &&
          nombreVistaActual != "Favoritos" &&
          nombreVistaActual != "Recientes" &&
          nombreVistaActual != "Más Escuchadas") {
        for (final p in playlistProvider.playlists) {
          if (p.name == nombreVistaActual) {
            playlistDeVistaActual = p;
            break;
          }
        }
      }
      final sePuedeQuitarConSwipe = esVistaDeFavoritos || playlistDeVistaActual != null;

      final textoBusqueda = _buscadorController.text.toLowerCase();
      List<Song> cancionesFiltradas = textoBusqueda.isEmpty
          ? cancionesBase
          : cancionesBase.where((c) => 
              c.title.toLowerCase().contains(textoBusqueda) || 
              c.artist.toLowerCase().contains(textoBusqueda) ||
              c.album.toLowerCase().contains(textoBusqueda)
            ).toList();

      final String tituloVista;
      if (mostrarInicio) {
        tituloVista = "Inicio";
      } else if (subFiltroSeleccionado != null) {
        tituloVista = (seccionActiva == "Tu Biblioteca" && bibliotecaSeleccionada == "Principal (Drive)")
            ? (subFiltroSeleccionado == "Principal (Drive)" ? "Toda tu música" : subFiltroSeleccionado!)
            : subFiltroSeleccionado!;
      } else {
        tituloVista = seccionActiva == "Tu Biblioteca" ? "Biblioteca: $bibliotecaSeleccionada" : seccionActiva;
      }

      widgetCentral = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (subFiltroSeleccionado != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.paper, size: 18),
                  tooltip: "Volver",
                  onPressed: () => setState(() => subFiltroSeleccionado = null),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  tituloVista,
                  style: AppTheme.heading.copyWith(fontSize: esPantallaPequena ? 20 : 24),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: "Actualizar canciones",
                icon: actualizando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppTheme.mutedInk),
                onPressed: actualizando ? null : _actualizarCanciones,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (mostrarInicio)
            Expanded(
              child: InicioTab(
                player: player,
                esPantallaPequena: esPantallaPequena,
                totalCanciones: canciones.length,
                recientes: cancionesParaNombre("Recientes"),
                masEscuchadas: cancionesParaNombre("Más Escuchadas"),
                favoritos: cancionesParaNombre("Favoritos"),
                recomendaciones: player.getRecommendations(canciones),
                playlists: playlistProvider.playlists,
                onRefrescar: _actualizarCanciones,
                onVerBibliotecaCompleta: () => setState(() => subFiltroSeleccionado = "Principal (Drive)"),
                onAbrirBuscadorOnline: () => setState(() {
                  seccionActiva = "Buscador Online";
                  subFiltroSeleccionado = null;
                }),
                onVerTodoRecientes: () => setState(() => subFiltroSeleccionado = "Recientes"),
                onVerTodoMasEscuchadas: () => setState(() => subFiltroSeleccionado = "Más Escuchadas"),
                onVerTodoPlaylists: () => setState(() {
                  seccionActiva = "Playlists";
                  subFiltroSeleccionado = null;
                }),
                onVerTodoFavoritos: () => setState(() => subFiltroSeleccionado = "Favoritos"),
                onVerTodoRecomendaciones: () => setState(() {
                  seccionActiva = "Recomendaciones";
                  subFiltroSeleccionado = null;
                }),
                onSeleccionarPlaylist: (nombre) => setState(() {
                  seccionActiva = "Playlists";
                  subFiltroSeleccionado = nombre;
                }),
                onIrASeccion: _cambiarSeccion,
              ),
            )
          else if (seccionActiva == "Playlists" && subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: "Playlists",
                elementos: nombresBibliotecas.where((b) => b != "Principal (Drive)").toList(),
                icono: Icons.playlist_play_rounded,
                esPantallaPequena: esPantallaPequena,
                onSeleccionarElemento: (nombre) => setState(() => subFiltroSeleccionado = nombre),
              ),
            )
          else if (seccionActiva == "Artistas" && subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: "Artistas",
                elementos: listaArtistas,
                icono: Icons.person_rounded,
                esPantallaPequena: esPantallaPequena,
                representativas: representativaPorArtista,
                onSeleccionarElemento: (nombre) => setState(() => subFiltroSeleccionado = nombre),
              ),
            )
          else if (seccionActiva == "Álbumes" && subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: "Álbumes",
                elementos: listaAlbumes,
                icono: Icons.album_rounded,
                esPantallaPequena: esPantallaPequena,
                representativas: representativaPorAlbum,
                onSeleccionarElemento: (nombre) => setState(() => subFiltroSeleccionado = nombre),
              ),
            )
          else ...[
            if (seccionActiva == "Tu Biblioteca")
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _buscadorController,
                  style: AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "¿Qué te apetece reproducir?",
                    hintStyle: AppTheme.body.copyWith(color: AppTheme.faintInk),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.faintInk),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
            if (cancionesFiltradas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => player.playSong(
                        cancionesFiltradas[0],
                        cancionesFiltradas,
                        0,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text("Reproducir"),
                      style: AppTheme.primaryButton,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final lista = List<Song>.from(cancionesFiltradas)..shuffle();
                        player.playSong(lista[0], lista, 0);
                      },
                      icon: const Icon(Icons.shuffle_rounded, size: 20),
                      label: const Text("Aleatorio"),
                      style: AppTheme.outlineButton,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: cancionesFiltradas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            textoBusqueda.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.music_off_rounded,
                            size: 56,
                            color: AppTheme.mutedInk,
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              textoBusqueda.isNotEmpty
                                  ? 'Sin resultados para "$textoBusqueda"'
                                  : _mensajeBibliotecaVacia(),
                              style: AppTheme.body.copyWith(fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _actualizarCanciones,
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      child: ListView.builder(
                        itemCount: cancionesFiltradas.length,
                        itemBuilder: (context, index) {
                          final cancion = cancionesFiltradas[index];
                          final estaSonando = player.currentSong?.id == cancion.id;
                          final descargando = player.isDownloading(cancion.id);

                          final fila = Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: estaSonando ? AppTheme.surfaceLight : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: esPantallaPequena,
                              onTap: () => player.playSong(cancion, cancionesFiltradas, index),
                              leading: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  SongCover(
                                    title: cancion.title,
                                    artist: cancion.artist,
                                    url: cancion.url,
                                    coverUrlDirecto: cancion.coverUrl,
                                    size: esPantallaPequena ? 44 : 52,
                                    borderRadius: BorderRadius.circular(6),
                                    showShadow: true,
                                  ),
                                  if (descargando)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (estaSonando && player.isPlaying)
                                    Positioned(
                                      right: -3,
                                      bottom: -3,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.ink,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const IndicadorSonando(),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                cancion.title,
                                style: TextStyle(
                                  color: estaSonando ? AppTheme.amber : AppTheme.paper,
                                  fontSize: esPantallaPequena ? 13 : 15,
                                  fontWeight: estaSonando ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                "${cancion.artist} • ${cancion.album}",
                                style: AppTheme.small.copyWith(fontSize: esPantallaPequena ? 11 : 12),
                              ),
                              trailing: _construirMenuAcciones(cancion),
                            ),
                          );

                          if (!sePuedeQuitarConSwipe) return fila;

                          return Dismissible(
                            key: ValueKey('swipe_${cancion.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.danger,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_outline, color: AppTheme.paper),
                            ),
                            onDismissed: (_) {
                              HapticFeedback.mediumImpact();
                              final provider = context.read<PlaylistProvider>();
                              if (esVistaDeFavoritos) {
                                provider.toggleFavorite(cancion.id);
                              } else if (playlistDeVistaActual != null) {
                                provider.removeSongFromPlaylist(playlistDeVistaActual.id, cancion.id);
                              }
                            },
                            child: fila,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ],
      );
    }

    Widget contenidoPrincipal = Container(
      color: AppTheme.background,
      padding: EdgeInsets.all(esPantallaPequena ? 16 : 24),
      child: cargando
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
            )
          : widgetCentral,
    );

    if (!esPantallaPequena) {
      return Scaffold(
        body: Row(
          children: [
            BarraLateral(
              seccionActiva: seccionActiva,
              bibliotecaSeleccionada: bibliotecaSeleccionada,
              bibliotecas: nombresBibliotecas,
              controladorNuevaBib: _nuevaBibController,
              onCambiarSeccion: (seccion) => setState(() {
                seccionActiva = seccion;
                subFiltroSeleccionado = null;
                if (seccion == "Tu Biblioteca") bibliotecaSeleccionada = "Principal (Drive)";
              }),
              onSeleccionarBiblioteca: (bib) => setState(() {
                bibliotecaSeleccionada = bib;
                seccionActiva = "Tu Biblioteca";
                subFiltroSeleccionado = null;
              }),
              onCrearBiblioteca: _crearBiblioteca,
              onEliminarBiblioteca: _mostrarMenuBiblioteca,
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
                            const Icon(Icons.more_horiz, color: AppTheme.mutedInk),
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
                            child: Icon(Icons.play_circle_filled, size: 40, color: AppTheme.mutedInk),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    // Sin esto, el botón/gesto de "atrás" de Android cerraba la app
    // directamente al estar en Playlists/Artistas/Álbumes/etc -- porque
    // esas secciones se muestran cambiando `seccionActiva` (un estado
    // interno), no empujando una ruta nueva al Navigator. Como no hay
    // ninguna ruta que Flutter pueda "despopear", el back del sistema
    // caía directo sobre esta pantalla (la raíz) y la cerraba. Ahora,
    // si no estamos ya en el home real, "atrás" navega un nivel para
    // adentro en vez de salir de la app.
    final enHome = seccionActiva == "Tu Biblioteca" && subFiltroSeleccionado == null;
    // Si el video de YouTube está en pantalla completa, "atrás" lo
    // minimiza en vez de navegar -- así nunca se pierde por accidente
    // al tocar atrás, tal como pasaba antes de este overlay.
    final videoExpandido = onlineVideo.hayVideo && !onlineVideo.minimizado;

    return PopScope(
      canPop: !videoExpandido && enHome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (videoExpandido) {
          onlineVideo.minimizar();
        } else if (subFiltroSeleccionado != null) {
          setState(() => subFiltroSeleccionado = null);
        } else {
          _volverAInicio();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.background,
              elevation: 0,
              title: Text("CACOCAPP", style: AppTheme.wordmark.copyWith(fontSize: 18)),
              iconTheme: const IconThemeData(color: AppTheme.paper),
            ),
            drawer: Drawer(
              backgroundColor: AppTheme.ink,
              child: BarraLateral(
                seccionActiva: seccionActiva,
                bibliotecaSeleccionada: bibliotecaSeleccionada,
                bibliotecas: nombresBibliotecas,
                controladorNuevaBib: _nuevaBibController,
                onCambiarSeccion: (seccion) {
                  setState(() {
                    seccionActiva = seccion;
                    subFiltroSeleccionado = null;
                    if (seccion == "Tu Biblioteca") bibliotecaSeleccionada = "Principal (Drive)";
                  });
                  Navigator.pop(context);
                },
                onSeleccionarBiblioteca: (bib) {
                  setState(() {
                    bibliotecaSeleccionada = bib;
                    seccionActiva = "Tu Biblioteca";
                    subFiltroSeleccionado = null;
                  });
                  Navigator.pop(context);
                },
                onCrearBiblioteca: _crearBiblioteca,
                onEliminarBiblioteca: _mostrarMenuBiblioteca,
              ),
            ),
            body: contenidoPrincipal,
            bottomNavigationBar: const SafeArea(
              child: MiniPlayer(),
            ),
          ),
          // Por encima de toda la pantalla (incluida la Drawer/AppBar)
          // para que el video se vea sin importar qué sección esté
          // activa por debajo.
          const OnlineVideoOverlay(),
        ],
      ),
    );
  }
}

