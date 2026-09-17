import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../utils/aviso_de_actualizacion.dart';
import '../utils/busqueda.dart';
import '../utils/secciones.dart';
import '../utils/bibliotecas_reservadas.dart';
import '../utils/nombre_archivo_parser.dart';
import '../utils/plural.dart';
import '../models/song.dart';
import '../providers/online_video_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/drive_service.dart';
import '../services/id3_cover_service.dart';
import '../services/musica_local_service.dart';
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

  String seccionActiva = seccionBiblioteca;
  String bibliotecaSeleccionada = bibliotecaPrincipal;
  String? subFiltroSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarCanciones();
    _buscadorController.addListener(() => setState(() {}));
  }

  /// La música que está guardada en el propio celular. Se guarda aparte
  /// de `canciones` para no perderla cuando se refresca la biblioteca
  /// del servidor, pero SE MUESTRA MEZCLADA con ella: no hay ninguna
  /// "sección de música local".
  List<Song> _delCelular = [];

  /// Cuántos archivos se dejaron afuera por no ser música (notas de voz
  /// de WhatsApp, grabaciones, tonos). Se muestra al actualizar.
  int _descartadosDelCelular = 0;

  /// Si la persona dio permiso para leer la música del celular.
  ///
  /// `null` mientras no venga al caso: en una computadora no hay
  /// ninguna música del teléfono que leer, así que no corresponde decir
  /// ni que sí ni que no.
  ///
  /// Sin esto, decir que no al permiso dejaba la app sin la música del
  /// celular **para siempre y sin ninguna explicación**: no aparecía, y
  /// no había forma de saber por qué ni cómo arreglarlo.
  bool? _hayPermisoDelCelular;

  /// La biblioteca completa: lo del servidor más lo del celular, en un
  /// solo orden alfabético.
  ///
  /// Todo lo demás de la app trabaja con esta lista y no sabe --ni le
  /// importa-- de dónde salió cada canción. Por eso la búsqueda, los
  /// favoritos, las playlists, Artistas, Álbumes y las estadísticas
  /// mezclan las dos cosas sin una línea de código extra.
  ///
  /// NO se sacan repetidas, a propósito. Si tenés la misma canción en
  /// el servidor y además guardada en el celular, son dos archivos
  /// distintos y las dos aparecen. Adivinar cuáles son "la misma" por
  /// el título terminaría escondiendo temas que no lo son --dos
  /// versiones, un vivo y un estudio-- y eso es peor que ver una
  /// repetida.
  ///
  /// SE GUARDA ARMADA, no se arma al dibujar.
  ///
  /// Nació como una propiedad que juntaba y ordenaba las dos listas
  /// cada vez que alguien la leía, y eso es una vez por DIBUJADO: o
  /// sea, con cada tecla del buscador y con cada aviso del reproductor,
  /// copiar y ordenar cientos de canciones para que den exactamente lo
  /// mismo. Las dos listas de las que sale cambian un puñado de veces
  /// en toda la sesión, así que se rearma ahí y no acá.
  List<Song> _biblioteca = [];

  /// Vuelve a juntar las dos listas. Hay que llamarla cada vez que
  /// cambia alguna de las dos.
  ///
  /// El orden se fija UNA vez, al juntarlas, y no se retoca cuando el
  /// repaso de metadatos corrige un título. Si se reordenara, las filas
  /// saltarían de lugar solas mientras la persona está mirando la
  /// lista, que es peor que un orden imperfecto.
  void _rearmarBiblioteca() {
    if (_delCelular.isEmpty) {
      _biblioteca = canciones;
      return;
    }
    final todas = [...canciones, ..._delCelular];
    // El orden ignora las tildes: con `toLowerCase()` a secas, "Ángel"
    // caía después de "Zeta", porque para la computadora la "Á" no está
    // cerca de la "A" sino después de todo el abecedario.
    todas.sort((a, b) => paraBuscar(a.title).compareTo(paraBuscar(b.title)));
    _biblioteca = todas;
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
      _rearmarBiblioteca();
    });
    // La del celular se busca DESPUÉS de mostrar la del servidor: pide
    // un permiso, y que lo primero que haga la app al abrirse sea tirar
    // un cartel del sistema encima de una pantalla vacía es desagradable.
    await _buscarMusicaDelCelular();
    if (!mounted) return;
    final player = context.read<PlayerProvider>();
    // Se restaura contra la biblioteca COMPLETA, no solo contra lo del
    // servidor. La sesión anterior se guarda como el id de la canción
    // que estaba sonando: si esa era una del celular y acá se buscara
    // solo entre las del servidor, no se encontraría y la app abriría
    // en la primera canción de la lista en vez de donde la dejaste.
    await player.restoreSession(_biblioteca);
    if (!mounted) return;
    // Esperamos a que las descargas (que pueden incluir canciones de
    // Jamendo/buscador online que NO están en `list`) terminen de leerse
    // de disco, para que una canción descargada agregada a una playlist
    // no "desaparezca" de esa playlist al reabrir la app.
    await player.whenDownloadsLoaded;
    if (!mounted) return;
    await context
        .read<PlaylistProvider>()
        .loadFromPrefs([...list, ..._delCelular, ...player.downloadedSongs]);
    // Sin esperar, a propósito: el repaso completa el álbum y el
    // artista de a poco por detrás, y la biblioteca ya está en
    // pantalla desde hace rato.
    unawaited(_resolverMetadataReal(list));
  }

  /// Busca la música guardada en el celular y la suma a la biblioteca.
  ///
  /// Se puede llamar cuantas veces haga falta. Android mantiene su
  /// propio índice de música al día solo --cuando llega un archivo
  /// nuevo por WhatsApp, por cable o desde otra app, lo agrega sin que
  /// nadie se lo pida--, así que no hay que hacer nada más que volver
  /// a preguntar para ver lo que se agregó después. Por eso también
  /// cuelga del botón de "Actualizar".
  Future<void> _buscarMusicaDelCelular({bool pedirPermiso = true}) async {
    if (!MusicaLocalService.disponible) return;
    final resultado = await MusicaLocalService.instance
        .buscar(pedirPermisoSiFalta: pedirPermiso);
    if (!mounted) return;
    setState(() {
      _delCelular = resultado.canciones;
      _descartadosDelCelular = resultado.descartadas;
      _hayPermisoDelCelular = resultado.hayPermiso;
      _rearmarBiblioteca();
    });
  }

  Future<void> _actualizarCanciones() async {
    setState(() => actualizando = true);
    try {
      final list = await _driveService.refrescarCanciones();
      if (!mounted) return;
      setState(() {
        canciones = list;
        actualizando = false;
        _rearmarBiblioteca();
      });
      final player = context.read<PlayerProvider>();
      await player.whenDownloadsLoaded;
      if (!mounted) return;
      // La música del celular se busca ANTES de restaurar las
      // playlists: las playlists se guardan como una lista de ids y al
      // cargarlas hay que poder resolver cada id contra una canción de
      // verdad. Si esto fuera después, una canción del celular metida
      // en una playlist no se encontraría y quedaría "sin resolver"
      // hasta la próxima vez que se abriera la app.
      await _buscarMusicaDelCelular(pedirPermiso: true);
      if (!mounted) return;
      await context
          .read<PlaylistProvider>()
          .loadFromPrefs([...list, ..._delCelular, ...player.downloadedSongs]);
      unawaited(_resolverMetadataReal(list));
      if (!mounted) return;
      // `refrescarCanciones` nunca falla hacia afuera: cuando el
      // servidor no contesta devuelve la lista de respaldo que viaja
      // dentro de la app. Antes el cartel decia "Biblioteca
      // actualizada" igual, asi que no habia forma de darse cuenta de
      // que el servidor estaba caido.
      final vinoDelServidor = _driveService.listaVieneDelWorker;

      // El texto completo se arma en `utils/aviso_de_actualizacion.dart`,
      // que tiene sus propios tests: son varias combinaciones y
      // equivocarse en una es decirle algo falso a la persona.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            avisoDeActualizacion(
              vinoDelServidor: vinoDelServidor,
              delServidor: list.length,
              delCelular: _delCelular.length,
              salteados: _descartadosDelCelular,
              hayPermisoDelCelular: _hayPermisoDelCelular,
            ),
            // Crema sobre ambar no se lee al sol; sobre el rojo de error
            // si. Ver `AppTheme.textoSobreAmbar`.
            style: vinoDelServidor ? AppTheme.textoSobreAmbar : null,
          ),
          backgroundColor: vinoDelServidor ? AppTheme.primary : AppTheme.danger,
          duration: const Duration(seconds: 3),
          // Decir que falta el permiso sin dar forma de darlo es media
          // ayuda: Android no vuelve a preguntar despues de dos "no",
          // asi que la unica salida es la pantalla de ajustes de la
          // app, y nadie sabe de memoria donde queda.
          action: _hayPermisoDelCelular == false
              ? const SnackBarAction(
                  label: 'Permitir',
                  textColor: AppTheme.paper,
                  onPressed: abrirAjustesParaDarElPermiso,
                )
              : null,
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
  /// Se incrementa con cada repaso lanzado, para poder abandonar el
  /// anterior.
  ///
  /// Hace falta porque "Actualizar" arma canciones NUEVAS: si tocás ese
  /// botón mientras el repaso inicial sigue corriendo, el repaso viejo
  /// se quedaba completando los datos de unas canciones que ya no se
  /// muestran en ninguna parte -- bajando medio megabyte por cada una,
  /// para nada. Es el mismo contador que ya usan las tres pantallas de
  /// búsqueda por el mismo motivo.
  int _generacionEscaneo = 0;

  Future<void> _resolverMetadataReal(List<Song> lista) async {
    const concurrencia = 6;
    final generacion = ++_generacionEscaneo;

    for (var i = 0; i < lista.length; i += concurrencia) {
      if (!mounted || generacion != _generacionEscaneo) return;
      // Cambia por lote, y se refresca la pantalla al terminar CADA
      // uno.
      //
      // Antes se refrescaba una sola vez, recién al terminar la
      // biblioteca entera. La primera vez que se abre la app no hay
      // nada guardado, así que cada tanda tiene que bajar medio
      // megabyte de seis canciones: con cientos de temas eso es medio
      // minuto largo mirando una lista que dice "Artista Desconocido"
      // en todas las filas, y de golpe se arregla entera. El dato de
      // las primeras ya estaba desde el principio y no se mostraba.
      //
      // Son unas pocas decenas de refrescos repartidos en ese medio
      // minuto: no se nota en rendimiento y cambia por completo cómo se
      // ve arrancar la app.
      var huboCambios = false;
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

      if (!mounted || generacion != _generacionEscaneo) return;
      if (huboCambios) setState(() {});
    }
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    _nuevaBibController.dispose();
    super.dispose();
  }

  String _mensajeBibliotecaVacia() {
    if (bibliotecaSeleccionada == bibliotecaFavoritos) {
      return "Todavía no tienes canciones favoritas.\nToca el corazón en cualquier canción para agregarla aquí.";
    }
    if (bibliotecaSeleccionada == bibliotecaRecientes) {
      return "Todavía no has reproducido ninguna canción.\nAparecerán aquí en cuanto empieces a escuchar.";
    }
    if (bibliotecaSeleccionada == bibliotecaMasEscuchadas) {
      return "Todavía no hay suficiente historial.\nEntre más escuches, más precisa será esta lista.";
    }
    if (bibliotecaSeleccionada == bibliotecaPrincipal) {
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
      seccionActiva = seccionBiblioteca;
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
        bibliotecaSeleccionada = bibliotecaPrincipal;
      }
      if (subFiltroSeleccionado == nombre) {
        subFiltroSeleccionado = null;
      }
    });
  }

  void _volverAInicio() {
    setState(() {
      seccionActiva = seccionBiblioteca;
      bibliotecaSeleccionada = bibliotecaPrincipal;
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
      if (seccion == seccionBiblioteca) {
        bibliotecaSeleccionada = bibliotecaPrincipal;
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

    // DE ACÁ PARA ABAJO, "la biblioteca" es una sola cosa.
    //
    // `canciones` es lo que vino del servidor y `_delCelular` lo que ya
    // estaba en el teléfono, pero esa diferencia se termina justo acá:
    // todo lo que sigue --la búsqueda, Artistas, Álbumes, Favoritos,
    // Recientes, las playlists, las recomendaciones-- trabaja con esta
    // lista única y no sabe de dónde salió cada canción.
    //
    // Es lo que hace que no haya "una cosa en un lado y otra en otro"
    // sin tener que tocar ninguna de esas pantallas.
    final biblioteca = _biblioteca;

    // TODAS las canciones que la app conoce, por id: las de la
    // biblioteca MÁS las descargadas.
    //
    // La diferencia importa para Favoritos, Recientes y Más Escuchadas.
    // Esas tres no son "parte de la biblioteca": son "cosas con las que
    // hiciste algo", y una canción de Descubrir que bajaste y
    // escuchaste es exactamente eso.
    //
    // Antes salían del listado de la biblioteca a secas, así que una
    // canción descargada de Jamendo se podía escuchar veinte veces y no
    // aparecía en Recientes ni en Más Escuchadas, y marcarla como
    // favorita no la mostraba en Favoritos. La app tenía su nombre, su
    // artista y su carátula guardados; simplemente no la buscaba ahí.
    //
    // El orden importa: las de la biblioteca van ÚLTIMAS para que, si
    // una canción está en las dos (una del servidor que además
    // descargaste), gane la de la biblioteca, que es la que tiene el
    // álbum y el artista ya corregidos con los datos del propio MP3.
    //
    // `late` para que solo se arme si alguien la lee, y una sola vez
    // aunque la lean las tres.
    late final Map<String, Song> porId = {
      for (final c in player.downloadedSongs) c.id: c,
      for (final c in biblioteca) c.id: c,
    };

    List<Song> cancionesParaNombre(String nombre) {
      if (nombre == bibliotecaPrincipal) return biblioteca;
      if (nombre == bibliotecaFavoritos) {
        return porId.values
            .where((c) => playlistProvider.isFavorite(c.id))
            .toList();
      }
      if (nombre == bibliotecaRecientes) {
        return player.historialIds
            .map((id) => porId[id])
            .whereType<Song>()
            .toList();
      }
      if (nombre == bibliotecaMasEscuchadas) {
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
      for (final c in biblioteca) {
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
    // Ordenados y sin los vacíos.
    //
    // Antes salían en el orden en que aparecían en la biblioteca --que
    // está ordenada por TÍTULO de canción--, así que la grilla de
    // Artistas quedaba en un orden que desde afuera parece al azar.
    //
    // Y los vacíos armaban una tarjeta sin nombre: pasa con los MP3 que
    // no traen el dato del álbum, que son muchos, y se notó más al
    // empezar a leer la música del propio celular.
    //
    // El orden ignora las tildes: si no, "Ángel" caía DESPUÉS de "Zeta",
    // porque para la computadora la "Á" no está cerca de la "A".
    late final List<String> listaArtistas =
        nombresOrdenados(biblioteca.map((c) => c.artist));
    late final List<String> listaAlbumes =
        nombresOrdenados(biblioteca.map((c) => c.album));
    late final Map<String, Song> representativaPorArtista =
        primeraPorClave((c) => c.artist);
    late final Map<String, Song> representativaPorAlbum =
        primeraPorClave((c) => c.album);

    Widget widgetCentral;
    if (seccionActiva == seccionEstadisticas) {
      widgetCentral = StatisticsScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == seccionRecomendaciones) {
      widgetCentral =
          RecommendationsScreen(allSongs: biblioteca, onVolver: _volverAInicio);
    } else if (seccionActiva == seccionDescubrir) {
      widgetCentral = DescubrirScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == seccionBuscadorOnline) {
      widgetCentral = DualSearchScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == seccionMusicaDescargada) {
      widgetCentral = DownloadedSongsView(onVolver: _volverAInicio);
    } else if (seccionActiva == seccionJuegos) {
      widgetCentral = JuegosScreen(onVolver: _volverAInicio);
    } else if (seccionActiva == seccionNoticias) {
      widgetCentral = NoticiasScreen(onVolver: _volverAInicio);
    } else {
      final mostrarInicio = seccionActiva == seccionBiblioteca &&
          bibliotecaSeleccionada == bibliotecaPrincipal &&
          subFiltroSeleccionado == null;

      List<Song> cancionesBase = [];
      if (seccionActiva == seccionBiblioteca && !mostrarInicio) {
        if (bibliotecaSeleccionada == bibliotecaPrincipal) {
          cancionesBase = cancionesParaNombre(subFiltroSeleccionado!);
        } else {
          cancionesBase = cancionesParaNombre(bibliotecaSeleccionada);
        }
      } else if (seccionActiva == seccionArtistas &&
          subFiltroSeleccionado != null) {
        cancionesBase =
            biblioteca.where((c) => c.artist == subFiltroSeleccionado).toList();
      } else if (seccionActiva == seccionAlbumes &&
          subFiltroSeleccionado != null) {
        cancionesBase =
            biblioteca.where((c) => c.album == subFiltroSeleccionado).toList();
      } else if (seccionActiva == seccionPlaylists &&
          subFiltroSeleccionado != null) {
        cancionesBase = cancionesParaNombre(subFiltroSeleccionado!);
      }

      final nombreVistaActual = (seccionActiva == seccionBiblioteca &&
              !mostrarInicio)
          ? (bibliotecaSeleccionada == bibliotecaPrincipal
              ? subFiltroSeleccionado
              : bibliotecaSeleccionada)
          : (seccionActiva == seccionPlaylists ? subFiltroSeleccionado : null);
      final esVistaDeFavoritos = nombreVistaActual == bibliotecaFavoritos;
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

      final textoBusqueda = _buscadorController.text.trim();
      // Ver `utils/busqueda.dart`: no distingue tildes y no le importa
      // el orden de las palabras. Antes buscar "corazon" no encontraba
      // "Corazón", que en una biblioteca en castellano deja afuera
      // medio catálogo.
      List<Song> cancionesFiltradas = textoBusqueda.isEmpty
          ? cancionesBase
          : cancionesBase
              .where((c) => coincideLaBusqueda(
                  textoBusqueda, [c.title, c.artist, c.album]))
              .toList();

      final String tituloVista;
      if (mostrarInicio) {
        tituloVista = "Inicio";
      } else if (subFiltroSeleccionado != null) {
        // Acá había tres condiciones anidadas cuyo único trabajo era
        // cambiar el nombre de la biblioteca principal por "Toda tu
        // música" al titular la pantalla. Ahora la biblioteca SE LLAMA
        // así, con lo cual las tres ramas daban el mismo resultado: el
        // nombre del filtro, tal cual.
        tituloVista = subFiltroSeleccionado!;
      } else {
        tituloVista = seccionActiva == seccionBiblioteca
            ? bibliotecaSeleccionada
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
                totalCanciones: biblioteca.length,
                recientes: cancionesParaNombre(bibliotecaRecientes),
                masEscuchadas: cancionesParaNombre(bibliotecaMasEscuchadas),
                favoritos: cancionesParaNombre(bibliotecaFavoritos),
                recomendaciones: player.getRecommendations(biblioteca),
                playlists: playlistProvider.playlists,
                onRefrescar: _actualizarCanciones,
                onVerBibliotecaCompleta: () =>
                    setState(() => subFiltroSeleccionado = bibliotecaPrincipal),
                onAbrirBuscadorOnline: () => setState(() {
                  seccionActiva = seccionBuscadorOnline;
                  subFiltroSeleccionado = null;
                }),
                onVerTodoRecientes: () =>
                    setState(() => subFiltroSeleccionado = bibliotecaRecientes),
                onVerTodoMasEscuchadas: () => setState(
                    () => subFiltroSeleccionado = bibliotecaMasEscuchadas),
                onVerTodoPlaylists: () => setState(() {
                  seccionActiva = seccionPlaylists;
                  subFiltroSeleccionado = null;
                }),
                onVerTodoFavoritos: () =>
                    setState(() => subFiltroSeleccionado = bibliotecaFavoritos),
                onVerTodoRecomendaciones: () => setState(() {
                  seccionActiva = seccionRecomendaciones;
                  subFiltroSeleccionado = null;
                }),
                onSeleccionarPlaylist: (nombre) => setState(() {
                  seccionActiva = seccionPlaylists;
                  subFiltroSeleccionado = nombre;
                }),
                onIrASeccion: _cambiarSeccion,
              ),
            )
          else if (seccionActiva == seccionPlaylists &&
              subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: seccionPlaylists,
                tituloSingular: "Playlist",
                elementos: nombresBibliotecas
                    .where((b) => b != bibliotecaPrincipal)
                    .toList(),
                icono: Icons.playlist_play_rounded,
                esPantallaPequena: esPantallaPequena,
                onSeleccionarElemento: (nombre) =>
                    setState(() => subFiltroSeleccionado = nombre),
              ),
            )
          else if (seccionActiva == seccionArtistas &&
              subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: seccionArtistas,
                tituloSingular: "Artista",
                elementos: listaArtistas,
                icono: Icons.person_rounded,
                esPantallaPequena: esPantallaPequena,
                representativas: representativaPorArtista,
                onSeleccionarElemento: (nombre) =>
                    setState(() => subFiltroSeleccionado = nombre),
              ),
            )
          else if (seccionActiva == seccionAlbumes &&
              subFiltroSeleccionado == null)
            Expanded(
              child: VistaSpotifyGrid(
                titulo: seccionAlbumes,
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
            if (seccionActiva == seccionBiblioteca)
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

                          // El color de "esta es la que suena" va en un
                          // `Material` y no en un `Container`.
                          //
                          // Envuelto en algo con color, el destello al
                          // tocar la fila queda TAPADO: el ListTile lo
                          // pinta sobre el `Material` más cercano, que
                          // quedaba por debajo. La fila respondía igual,
                          // pero se sentía muerta al tocarla, que en una
                          // lista de cientos de canciones es lo que más
                          // se toca de toda la app.
                          //
                          // Flutter avisa de esto, pero el aviso solo
                          // aparece al correr un test de pantalla. Se
                          // encontró cuando se escribieron los primeros.
                          final fila = Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: estaSonando
                                  ? AppTheme.surfaceLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              clipBehavior: Clip.antiAlias,
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
                                  bibliotecaSeleccionada:
                                      bibliotecaSeleccionada,
                                ),
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
          seccionActiva = seccionBiblioteca;
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
    final enHome = seccionActiva == seccionBiblioteca &&
        subFiltroSeleccionado == null &&
        bibliotecaSeleccionada == bibliotecaPrincipal;
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
                    if (seccion == seccionBiblioteca) {
                      bibliotecaSeleccionada = bibliotecaPrincipal;
                    }
                  });
                  Navigator.pop(context);
                },
                onSeleccionarBiblioteca: (bib) {
                  setState(() {
                    bibliotecaSeleccionada = bib;
                    seccionActiva = seccionBiblioteca;
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
