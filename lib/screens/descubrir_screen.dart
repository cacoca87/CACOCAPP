import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/jamendo_service.dart';
import '../styles/app_theme.dart';
import '../widgets/boton_volver.dart';
import '../widgets/fila_de_generos.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/song_cover.dart';
import '../widgets/song_options_menu.dart';

/// Buscar y reproducir música de Jamendo (catálogo Creative Commons,
/// audio completo) — sin salir nunca de la app: el resultado se
/// reproduce con el mismo reproductor que usás para tu biblioteca del
/// Drive, y se puede favoritear/agregar a playlist/descargar offline
/// igual que cualquier otra canción, porque para el resto de la app
/// es un Song más.
class DescubrirScreen extends StatefulWidget {
  final VoidCallback? onVolver;

  const DescubrirScreen({super.key, this.onVolver});

  @override
  State<DescubrirScreen> createState() => _DescubrirScreenState();
}

class _DescubrirScreenState extends State<DescubrirScreen> {
  final TextEditingController _controlador = TextEditingController();
  Timer? _debounce;

  List<Song> _resultados = [];
  bool _buscando = false;
  String? _error;
  bool _yaHizoAlgunaBusqueda = false;
  String? _generoActivo; // para resaltar el chip elegido, si vino de ahí

  // Ver la nota del mismo contador en `dual_search_screen.dart`:
  // cancelar el temporizador no frena una búsqueda que ya salió a la
  // red, así que sin esto una consulta lenta podía llegar tarde y
  // pisar los resultados de la búsqueda (o el género) que el usuario
  // acababa de pedir.
  int _generacionBusqueda = 0;

  // La última consulta lanzada, para poder repetirla desde el botón
  // "Reintentar" sin que el usuario tenga que reescribir nada.
  Future<List<Song>> Function()? _ultimaConsulta;

  /// Se llama en cada tecla. Espera 450ms de silencio antes de buscar
  /// de verdad — así no disparamos una búsqueda de red por cada letra
  /// que se escribe, solo cuando la persona hace una pausa.
  void _onTextoCambio(String texto) {
    _debounce?.cancel();
    if (texto.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _yaHizoAlgunaBusqueda = false;
        _generoActivo = null;
        _error = null;
      });
      return;
    }
    // Se refresca en cada tecla por dos motivos: para que aparezca el
    // botón de borrar apenas empezás a escribir (antes tardaba hasta
    // que la búsqueda terminara, casi medio segundo más la red), y para
    // apagar el chip del género -- si venías de tocar "Rock" y después
    // escribís otra cosa, el chip quedaba encendido marcando un género
    // que ya no tenía nada que ver con lo que estabas viendo.
    setState(() => _generoActivo = null);
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _ejecutarBusqueda(() => JamendoService.instance.buscar(texto));
    });
  }

  void _buscarGenero(String etiqueta, String tag) {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _controlador.clear();
      _generoActivo = etiqueta;
    });
    _ejecutarBusqueda(() => JamendoService.instance.buscarPorGenero(tag));
  }

  Future<void> _ejecutarBusqueda(Future<List<Song>> Function() consulta) async {
    final generacion = ++_generacionBusqueda;
    _ultimaConsulta = consulta;
    setState(() {
      _buscando = true;
      _error = null;
      _yaHizoAlgunaBusqueda = true;
    });
    try {
      final resultados = await consulta();
      if (!mounted || generacion != _generacionBusqueda) return;
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted || generacion != _generacionBusqueda) return;
      setState(() {
        // El mensaje es para quien USA la app, no para quien la
        // programa. Antes acá salía "Falta configurar el client_id de
        // Jamendo en jamendo_service.dart": una instrucción para el
        // programador, en la cara de la persona que solo quería
        // escuchar música. Esa clave ya está puesta, así que ese texto
        // ni siquiera podía aparecer -- pero si algún día vuelve a
        // faltar, lo que corresponde mostrar es que el servicio no está
        // disponible, no un archivo de código.
        _error = JamendoService.instance.configurado
            ? 'No se pudo buscar. Revisá tu conexión e intentá de nuevo.'
            : 'El catálogo de Descubrir no está disponible en esta versión '
                'de la app.';
        _buscando = false;
      });
    }
  }

  /// Vuelve a lanzar la última consulta tal cual (texto o género).
  /// Hace falta para el botón "Reintentar" del estado de error: el
  /// fallo más común acá es la conexión, y volver a escribir toda la
  /// búsqueda para reintentar no tenía sentido.
  void _repetirUltimaBusqueda() {
    final consulta = _ultimaConsulta;
    if (consulta == null) return;
    _ejecutarBusqueda(consulta);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title: Text('Descubrir',
            style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: BotonVolver(onVolver: widget.onVolver),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _controlador,
                style:
                    AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 14),
                textInputAction: TextInputAction.search,
                onChanged: _onTextoCambio,
                // La tecla de "buscar" del teclado baja el teclado y
                // busca ya, sin esperar el medio segundo de pausa.
                // Antes no hacía nada y el teclado tapaba justo los
                // resultados que acababas de pedir.
                onSubmitted: (texto) {
                  _debounce?.cancel();
                  FocusScope.of(context).unfocus();
                  if (texto.trim().isEmpty) return;
                  _ejecutarBusqueda(
                      () => JamendoService.instance.buscar(texto));
                },
                decoration: InputDecoration(
                  hintText: "Buscar en Jamendo (título, artista)...",
                  hintStyle: AppTheme.body.copyWith(color: AppTheme.faintInk),
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.faintInk),
                  suffixIcon: _controlador.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: "Borrar búsqueda",
                          icon: const Icon(Icons.close,
                              color: AppTheme.faintInk, size: 18),
                          onPressed: () {
                            _debounce?.cancel();
                            setState(() {
                              _controlador.clear();
                              _resultados = [];
                              _yaHizoAlgunaBusqueda = false;
                              _generoActivo = null;
                            });
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ),

          // Ver `widgets/fila_de_generos.dart`: vive aparte para poder
          // probarla, y ya no lleva ningún alto escrito a mano.
          FilaDeGeneros(
            generoActivo: _generoActivo,
            onElegirGenero: _buscarGenero,
          ),
          const SizedBox(height: 12),

          if (_buscando)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: CircularProgressIndicator(color: AppTheme.amber),
            )
          else if (_error != null)
            Expanded(
              child: EstadoVacio(
                icono: Icons.cloud_off_rounded,
                mensaje: _error!,
                // La misma acción que en Noticias: un error sin forma de
                // reintentar obligaba a volver a escribir la búsqueda.
                accion: ElevatedButton.icon(
                  style: AppTheme.primaryButton,
                  onPressed: _repetirUltimaBusqueda,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reintentar'),
                ),
              ),
            )
          else if (!_yaHizoAlgunaBusqueda)
            const Expanded(
              child: EstadoVacio(
                icono: Icons.travel_explore_rounded,
                mensaje: 'Escribí algo o tocá un género. Jamendo tiene un '
                    'catálogo de artistas independientes con licencia libre, '
                    'y suena acá mismo sin salir de la app.',
              ),
            )
          else if (_resultados.isEmpty)
            const Expanded(
              child: EstadoVacio(
                icono: Icons.search_off_rounded,
                mensaje: 'No se encontró nada con esa búsqueda. Probá con '
                    'otras palabras o elegí un género de arriba.',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _resultados.length,
                itemBuilder: (context, index) {
                  final cancion = _resultados[index];
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
                      "${cancion.artist} · ${cancion.album}",
                      style: AppTheme.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Mismo menú que en el resto de las listas de la app.
                    // Antes acá solo había un corazón, así que desde
                    // Descubrir no se podía agregar a playlist ni
                    // descargar, aunque el comentario de arriba de este
                    // archivo decía que sí.
                    trailing: SongOptionsMenu(
                      cancion: cancion,
                      // No es una playlist: ver la nota en `SongOptionsMenu`.
                      bibliotecaSeleccionada: null,
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      player.playSong(cancion, _resultados, index);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
