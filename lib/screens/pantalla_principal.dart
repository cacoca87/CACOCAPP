import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../utils/bibliotecas_reservadas.dart';
import '../utils/nombre_archivo_parser.dart';
import '../utils/plural.dart';
import '../models/song.dart';
import '../providers/online_video_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/drive_service.dart';
import '../services/id3_cover_service.dart';
import '../styles/app_theme.dart';
import '../widgets/barra_lateral.dart';
import '../widgets/boton_volver.dart';
import '../widgets/inicio_tab.dart';
import '../widgets/indicador_sonando.dart';
import '../widgets/mini_player.dart';
import '../widgets/online_video_overlay.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/song_cover.dart';
import '../widgets/song_options_menu.dart';
import '../widgets/vista_spotify_grid.dart';
import 'statistics_screen.dart';
import 'recommendations_screen.dart';
import 'descubrir_screen.dart';
import 'downloaded_songs_view.dart';
import 'juegos_screen.dart';
import 'noticias_screen.dart';
import 'dual_search_screen.dart';
import 'pantalla_principal_desktop.dart';

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
    // La comprobación va ANTES del `setState`, no después: si la pantalla
    // se desmontó mientras la biblioteca venía de la red, actualizar el
    // estado de un widget que ya no existe es un error en tiempo de
    // ejecución. Estaba al revés.
    if (!mounted) return;
    setState(() {
      canciones = list;
      cargando = false;
    });
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
    _resolverMetadataReal(list);
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
      _resolverMetadataReal(list);
      if (!mounted) return;
      // `refrescarCanciones` nunca falla hacia afuera: cuando el
      // servidor no contesta devuelve la lista de respaldo que viaja
      // dentro de la app. Antes el cartel decia "Biblioteca
      // actualizada" igual, asi que no habia forma de darse cuenta de
      // que el servidor estaba caido.
      final vinoDelServidor = _driveService.listaVieneDelWorker;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vinoDelServidor
                ? "Biblioteca actualizada: ${contarCanciones(list.length)}"
                : "No se pudo consultar el servidor. Se muestra la lista "
                    "guardada: ${contarCanciones(list.length)}",
            // Crema sobre ambar no se lee al sol; sobre el rojo de error
            // si. Ver `AppTheme.textoSobreAmbar`.
            style: vinoDelServidor ? AppTheme.textoSobreAmbar : null,
          ),
          backgroundColor: vinoDelServidor ? AppTheme.primary : AppTheme.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => actualizando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo actualizar. Revisa tu conexión."),
          backgroundColor: AppTheme.danger,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Reemplaza el álbum/artista "adivinados" a partir del nombre del
  /// archivo (`DriveService`) por los reales del tag ID3, cuando el
  /// propio MP3 los trae. El artista importa especialmente: cuando el
  /// nombre del archivo no sigue el patrón "Artista - Canción.mp3"
  /// (ej. "Runnin' Down A Dream.mp3"), `DriveService` no tiene forma
  /// de adivinarlo y queda como "Artista Desconocido" para siempre --
  /// aunque el MP3 sí traiga el artista real en su tag (TPE1).
  Future<void> _resolverMetadataReal(List<Song> lista) async {
    const concurrencia = 6;
    var huboCambios = false;

    for (var i = 0; i < lista.length; i += concurrencia) {
      if (!mounted) return;
      final lote = lista.skip(i).take(concurrencia);
      await Future.wait(lote.map((cancion) async {
        final album =
            await Id3CoverService.instance.getEmbeddedAlbum(cancion.url);
        if (album != null && album.isNotEmpty && album != cancion.album) {
          cancion.album = album;
          huboCambios = true;
        }

        final artista =
            await Id3CoverService.instance.getEmbeddedArtist(cancion.url);
        if (artista != null &&
            artista.isNotEmpty &&
            artista != cancion.artist) {
          cancion.artist = artista;
          huboCambios = true;

          // Sabiendo quién es el artista de verdad, el nombre del
          // archivo deja de ser una adivinanza. Si empieza con el
          // artista, entonces el título es el resto -- y eso corrige de
          // una los discos nombrados "Artista - Canción", que hasta
          // ahora quedaban con el título y el artista cambiados.
          //
          // Sale gratis: usa el dato que ya se acaba de pedir, sin una
          // sola descarga más.
          final tituloCorregido = tituloSabiendoElArtista(
            nombreDeArchivoDeUrl(cancion.url),
            artista,
          );
          if (tituloCorregido != null && tituloCorregido != cancion.title) {
            cancion.title = tituloCorregido;
          }
        }
        // El título REAL (tag TIT2) no se pide acá a propósito, aunque
        // se podría: las canciones que ya tienen álbum y artista
        // guardados en el celular NO tienen el título, así que pedirlo
        // para toda la biblioteca obligaría a volver a bajar medio
        // megabyte de cada una. Con cientos de canciones eso es más de
        // cien megas de datos móviles de golpe, sin que nadie lo haya
        // pedido.
        //
        // En vez de eso se resuelve donde de verdad importa y de a una:
        // al abrir la Letra de una canción (ver `lyrics_screen.dart`),
        // que es justo donde el título equivocado hace daño.
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

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), duration: const Duration(seconds: 3)),
    );
  }

  void _crearBiblioteca() {
    final nombre = _nuevaBibController.text.trim();
    final provider = context.read<PlaylistProvider>();

    // Antes estos casos hacían `return` en silencio: tocabas "crear",
    // no pasaba nada, y no había forma de saber por qué. Las reglas
    // viven en `utils/bibliotecas_reservadas.dart` para que los tres
    // lugares que crean o renombran playlists usen las mismas.
    final error = errorDeNombreDeBiblioteca(
      nombre,
      nombresExistentes: provider.playlists.map((p) => p.name),
    );
    if (error != null) {
      // El campo vacío no merece un cartel: simplemente no hace nada.
      if (nombre.isNotEmpty) _avisar(error);
      return;
    }

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
              title: Text("Renombrar",
                  style: AppTheme.body.copyWith(color: AppTheme.paper)),
              onTap: () => Navigator.pop(context, "renombrar"),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: Text("Eliminar",
                  style: AppTheme.body.copyWith(color: AppTheme.danger)),
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
        title: Text("Renombrar playlist",
            style: AppTheme.subheading.copyWith(fontSize: 17)),
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
            child: Text("Cancelar",
                style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controlador.text.trim()),
            style: AppTheme.primaryButton,
            child: const Text("Guardar"),
          ),
        ],
      ),
    );

    // El diálogo ya se cerró: el controlador no lo usa nadie más. Sin
    // esto quedaba vivo para siempre, uno nuevo por cada vez que se
    // abriera el diálogo.
    controlador.dispose();

    if (nuevoNombre == null ||
        nuevoNombre.isEmpty ||
        nuevoNombre == nombreActual) {
      return;
    }
    if (!mounted) return;

    // Las mismas reglas que al crear una biblioteca, del mismo lugar
    // (`utils/bibliotecas_reservadas.dart`). Antes acá no se validaba
    // nada: se podía renombrar una playlist a "Favoritos" (que es una
    // vista propia de la app) o al nombre de otra que ya existía, y
    // como las bibliotecas se buscan por nombre, la segunda quedaba
    // inalcanzable.
    final error = errorDeNombreDeBiblioteca(
      nuevoNombre,
      nombresExistentes: playlistProvider.playlists.map((p) => p.name),
      nombreQueSeReemplaza: nombreActual,
    );
    if (error != null) {
      _avisar(error);
      return;
    }

    playlistProvider.renamePlaylist(playlistARenombrar.id, nuevoNombre);
    setState(() {
      if (bibliotecaSeleccionada == nombreActual) {
        bibliotecaSeleccionada = nuevoNombre;
      }
      if (subFiltroSeleccionado == nombreActual) {
        subFiltroSeleccionado = nuevoNombre;
      }
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
        title: Text("¿Eliminar playlist?",
            style: AppTheme.subheading.copyWith(fontSize: 17)),
        content: Text(
          'Se eliminará "$nombre" con sus ${contarCanciones(playlistAEliminar.songs.length)}. Las canciones en sí no se borran, solo esta playlist.',
          style: AppTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar",
                style: AppTheme.body.copyWith(color: AppTheme.mutedInk)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: AppTheme.paper,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
      if (seccion == "Tu Biblioteca") {
        bibliotecaSeleccionada = "Principal (Drive)";
      }
    });
  }

  // El menú "más opciones" de cada canción (favoritos, descargar,
  // agregar a playlist) vive en su propio widget autocontenido:
  // ver `SongOptionsMenu` en lib/widgets/song_options_menu.dart.

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final onlineVideo = context.watch<OnlineVideoProvider>();
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esPantallaPequena = anchoPantalla < 800;

    final List<String> nombresBibliotecas = [
      ...nombresReservadosDeBiblioteca,
      ...playlistProvider.playlists.map((p) => p.name),
    ];

    List<Song> cancionesParaNombre(String nombre) {
      if (nombre == "Principal (Drive)") return canciones;
      if (nombre == "Favoritos") {
        return canciones
            .where((c) => playlistProvider.isFavorite(c.id))
            .toList();
      }
      if (nombre == "Recientes") {
        final porId = {for (final c in canciones) c.id: c};
        return player.historialIds
            .map((id) => porId[id])
            .whereType<Song>()
            .toList();
      }
      if (nombre == "Más Escuchadas") {
        final porId = {for (final c in canciones) c.id: c};
        return player.masEscuchadasIds
            .map((id) => porId[id])
            .whereType<Song>()
            .toList();
      }
      for (final p in playlistProvider.playlists) {
        // Copia: `p.songs` es la lista interna de la playlist, y quien
        // la reciba no tiene por qué poder modificarla sin querer.
        if (p.name == nombre) return List<Song>.from(p.songs);
      }
      return [];
    }

    /// La primera canción de cada artista / de cada álbum, para usar su
    /// carátula como portada del grupo.
    Map<String, Song> primeraPorClave(String Function(Song) clave) {
      final mapa = <String, Song>{};
      for (final c in canciones) {
        mapa.putIfAbsent(clave(c), () => c);
      }
      return mapa;
    }

    // `late` a propósito: en Dart una variable local `late` se calcula
    // la primera vez que se LEE, no acá. Y estas cuatro solo se leen en
    // las vistas de Artistas y de Álbumes.
    //
    // Antes se calculaban siempre: cuatro recorridas enteras de la
    // biblioteca (cientos de canciones) en cada `build`, y este `build`
    // corre con cada tecla que se escribe en el buscador y con cada
    // aviso del reproductor -- incluso estando en Juegos o Noticias,
    // donde no se usan para nada.
    late final List<String> listaArtistas =
        canciones.map((c) => c.artist).toSet().toList();
    late final List<String> listaAlbumes =
        canciones.map((c) => c.album).toSet().toList();
    late final Map<String, Song> representativaPorArtista =
        primeraPorClave((c) => c.artist);
    late final Map<String, Song> representativaPorAlbum =
        primeraPorClave((c) => c.album);

    Widget widgetCentral;
    if (seccionActiva == "Estadísticas") {
      widgetCentral = StatisticsScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == "Recomendaciones") {
      widgetCentral =
          RecommendationsScreen(allSongs: canciones, onVolver: _volverAInicio);
    } else if (seccionActiva == "Descubrir") {
      widgetCentral = DescubrirScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == "Buscador Online") {
      widgetCentral = DualSearchScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == "Música Descargada") {
      widgetCentral = DownloadedSongsView(onVolver: _volverAInicio);
    } else if (seccionActiva == "Juegos") {
      widgetCentral = JuegosScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == "Noticias") {
      widgetCentral = NoticiasScreen(onVolver: _volverAInicio);
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
        cancionesBase =
            canciones.where((c) => c.artist == subFiltroSeleccionado).toList();
      } else if (seccionActiva == "Álbumes" && subFiltroSeleccionado != null) {
        cancionesBase =
            canciones.where((c) => c.album == subFiltroSeleccionado).toList();
      } else if (seccionActiva == "Playlists" &&
          subFiltroSeleccionado != null) {
        cancionesBase = cancionesParaNombre(subFiltroSeleccionado!);
      }

      final nombreVistaActual =
          (seccionActiva == "Tu Biblioteca" && !mostrarInicio)
              ? (bibliotecaSeleccionada == "Principal (Drive)"
                  ? subFiltroSeleccionado
                  : bibliotecaSeleccionada)
              : (seccionActiva == "Playlists" ? subFiltroSeleccionado : null);
      final esVistaDeFavoritos = nombreVistaActual == "Favoritos";
      Playlist? playlistDeVistaActual;
      if (nombreVistaActual != null &&
          !nombresReservadosDeBiblioteca.contains(nombreVistaActual)) {
        for (final p in playlistProvider.playlists) {
          if (p.name == nombreVistaActual) {
            playlistDeVistaActual = p;
            break;
          }
        }
      }
      final sePuedeQuitarConSwipe =
          esVistaDeFavoritos || playlistDeVistaActual != null;

      final textoBusqueda = _buscadorController.text.toLowerCase();
      List<Song> cancionesFiltradas = textoBusqueda.isEmpty
          ? cancionesBase
          : cancionesBase
              .where((c) =>
                  c.title.toLowerCase().contains(textoBusqueda) ||
                  c.artist.toLowerCase().contains(textoBusqueda) ||
                  c.album.toLowerCase().contains(textoBusqueda))
              .toList();

      final String tituloVista;
      if (mostrarInicio) {
        tituloVista = "Inicio";
      } else if (subFiltroSeleccionado != null) {
        tituloVista = (seccionActiva == "Tu Biblioteca" &&
                bibliotecaSeleccionada == "Principal (Drive)")
            ? (subFiltroSeleccionado == "Principal (Drive)"
                ? "Toda tu música"
                : subFiltroSeleccionado!)
            : subFiltroSeleccionado!;
      } else {
        tituloVista = seccionActiva == "Tu Biblioteca"
            ? "Biblioteca: $bibliotecaSeleccionada"
            : seccionActiva;
      }

      widgetCentral = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (subFiltroSeleccionado != null) ...[
                BotonVolver(
                  compacto: true,
                  onVolver: () => setState(() => subFiltroSeleccionado = null),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  tituloVista,
                  style: AppTheme.heading
                      .copyWith(fontSize: esPantallaPequena ? 20 : 24),
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
                    : const Icon(Icons.refresh_rounded,
                        color: AppTheme.mutedInk),
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
                onVerBibliotecaCompleta: () =>
                    setState(() => subFiltroSeleccionado = "Principal (Drive)"),
                onAbrirBuscadorOnline: () => setState(() {
                  seccionActiva = "Buscador Online";
                  subFiltroSeleccionado = null;
                }),
                onVerTodoRecientes: () =>
                    setState(() => subFiltroSeleccionado = "Recientes"),
                onVerTodoMasEscuchadas: () =>
                    setState(() => subFiltroSeleccionado = "Más Escuchadas"),
                onVerTodoPlaylists: () => setState(() {
                  seccionActiva = "Playlists";
                  subFiltroSeleccionado = null;
                }),
                onVerTodoFavoritos: () =>
                    setState(() => subFiltroSeleccionado = "Favoritos"),
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
          else if (seccionActiva == "Playlists" &&
              subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: "Playlists",
                tituloSingular: "Playlist",
                elementos: nombresBibliotecas
                    .where((b) => b != "Principal (Drive)")
                    .toList(),
                icono: Icons.playlist_play_rounded,
                esPantallaPequena: esPantallaPequena,
                onSeleccionarElemento: (nombre) =>
                    setState(() => subFiltroSeleccionado = nombre),
              ),
            )
          else if (seccionActiva == "Artistas" && subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: "Artistas",
                tituloSingular: "Artista",
                elementos: listaArtistas,
                icono: Icons.person_rounded,
                esPantallaPequena: esPantallaPequena,
                representativas: representativaPorArtista,
                onSeleccionarElemento: (nombre) =>
                    setState(() => subFiltroSeleccionado = nombre),
              ),
            )
          else if (seccionActiva == "Álbumes" && subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: "Álbumes",
                tituloSingular: "Álbum",
                elementos: listaAlbumes,
                icono: Icons.album_rounded,
                esPantallaPequena: esPantallaPequena,
                representativas: representativaPorAlbum,
                onSeleccionarElemento: (nombre) =>
                    setState(() => subFiltroSeleccionado = nombre),
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
                  style: AppTheme.body
                      .copyWith(color: AppTheme.paper, fontSize: 14),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: "¿Qué te apetece reproducir?",
                    hintStyle: AppTheme.body.copyWith(color: AppTheme.faintInk),
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.faintInk),
                    // El mismo boton de borrar que ya tenia el buscador
                    // de Descubrir: sin esto habia que borrar el texto
                    // letra por letra.
                    suffixIcon: _buscadorController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: "Borrar búsqueda",
                            icon: const Icon(Icons.close,
                                color: AppTheme.faintInk, size: 18),
                            onPressed: () => _buscadorController.clear(),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                ),
              ),
            if (cancionesFiltradas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                // Wrap y no Row: con la letra del sistema agrandada los
                // dos botones no entraban en el ancho de un celular y se
                // desbordaban. Asi el segundo baja solo cuando hace
                // falta.
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
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
                    OutlinedButton.icon(
                      onPressed: () {
                        final lista = List<Song>.from(cancionesFiltradas)
                          ..shuffle();
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
                  ? EstadoVacio(
                      icono: textoBusqueda.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.music_off_rounded,
                      mensaje: textoBusqueda.isNotEmpty
                          ? 'Sin resultados para "$textoBusqueda"'
                          : _mensajeBibliotecaVacia(),
                    )
                  : RefreshIndicator(
                      onRefresh: _actualizarCanciones,
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      child: ListView.builder(
                        itemCount: cancionesFiltradas.length,
                        itemBuilder: (context, index) {
                          final cancion = cancionesFiltradas[index];
                          final estaSonando =
                              player.currentSong?.id == cancion.id;
                          final descargando = player.isDownloading(cancion.id);

                          final fila = Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: estaSonando
                                  ? AppTheme.surfaceLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: esPantallaPequena,
                              onTap: () => player.playSong(
                                  cancion, cancionesFiltradas, index),
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
                                          color: Colors.black
                                              .withValues(alpha: 0.55),
                                          borderRadius:
                                              BorderRadius.circular(6),
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
                                // Sin limite de renglones, un titulo
                                // largo partia la fila en dos y la lista
                                // quedaba despareja.
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: estaSonando
                                      ? AppTheme.amber
                                      : AppTheme.paper,
                                  fontSize: esPantallaPequena ? 13 : 15,
                                  fontWeight: estaSonando
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                "${cancion.artist} • ${cancion.album}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.small.copyWith(
                                    fontSize: esPantallaPequena ? 11 : 12),
                              ),
                              trailing: SongOptionsMenu(
                                cancion: cancion,
                                bibliotecaSeleccionada: bibliotecaSeleccionada,
                              ),
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
                              child: const Icon(Icons.delete_outline,
                                  color: AppTheme.paper),
                            ),
                            onDismissed: (_) {
                              HapticFeedback.mediumImpact();
                              final provider = context.read<PlaylistProvider>();
                              final playlistDeEsteSwipe = playlistDeVistaActual;
                              if (esVistaDeFavoritos) {
                                provider.toggleFavorite(cancion.id);
                              } else if (playlistDeEsteSwipe != null) {
                                provider.removeSongFromPlaylist(
                                    playlistDeEsteSwipe.id, cancion.id);
                              }
                              // Un deslizamiento sin querer borraba la
                              // cancion de la playlist sin aviso ni forma
                              // de volver atras.
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '"${cancion.title}" se quitó de la lista'),
                                    duration: const Duration(seconds: 4),
                                    action: SnackBarAction(
                                      label: "Deshacer",
                                      textColor: AppTheme.amber,
                                      onPressed: () {
                                        if (esVistaDeFavoritos) {
                                          provider.toggleFavorite(cancion.id);
                                        } else if (playlistDeEsteSwipe !=
                                            null) {
                                          provider.addSongToPlaylist(
                                              playlistDeEsteSwipe.id, cancion);
                                        }
                                      },
                                    ),
                                  ),
                                );
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
      return PantallaPrincipalDesktop(
        seccionActiva: seccionActiva,
        bibliotecaSeleccionada: bibliotecaSeleccionada,
        bibliotecas: nombresBibliotecas,
        controladorNuevaBib: _nuevaBibController,
        contenidoPrincipal: contenidoPrincipal,
        onCambiarSeccion: _cambiarSeccion,
        onSeleccionarBiblioteca: (bib) => setState(() {
          bibliotecaSeleccionada = bib;
          seccionActiva = "Tu Biblioteca";
          subFiltroSeleccionado = null;
        }),
        onCrearBiblioteca: _crearBiblioteca,
        onEliminarBiblioteca: _mostrarMenuBiblioteca,
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
    // Se exige tambien estar en la biblioteca principal: si estabas
    // mirando "Favoritos" o una playlist, "atras" cerraba la app en vez
    // de volver a la biblioteca.
    final enHome = seccionActiva == "Tu Biblioteca" &&
        subFiltroSeleccionado == null &&
        bibliotecaSeleccionada == "Principal (Drive)";
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
              title: Text("CACOCAPP",
                  style: AppTheme.wordmark.copyWith(fontSize: 18)),
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
                    if (seccion == "Tu Biblioteca") {
                      bibliotecaSeleccionada = "Principal (Drive)";
                    }
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
