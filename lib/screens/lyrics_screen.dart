import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';
import '../styles/app_theme.dart';
import '../widgets/estado_vacio.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  Future<Lyrics>? _future;
  String? _songIdCargado;
  final ScrollController _scrollController = ScrollController();
  int _ultimaLineaResaltada = -1;

  static const double _alturaPorLinea = 56.0;

  /// Si la canción actual cambió desde la última vez, dispara una
  /// nueva búsqueda. Se llama desde build() — al mutar los campos acá
  /// (sin setState) el propio build ya refleja el cambio, así que no
  /// hace falta nada más.
  void _asegurarCargaParaCancion(Song? song) {
    if (song == null || _songIdCargado == song.id) return;
    _songIdCargado = song.id;
    _ultimaLineaResaltada = -1;
    _future = LyricsService.instance.getLyrics(
      title: song.title,
      artist: song.artist,
      urlCancion: song.url,
    );
  }

  int _indiceLineaActual(List<LineaLetra> lineas, Duration posicion) {
    var indice = -1;
    for (var i = 0; i < lineas.length; i++) {
      if (lineas[i].tiempo <= posicion) {
        indice = i;
      } else {
        break;
      }
    }
    return indice;
  }

  void _scrollALinea(int indice) {
    if (indice < 0 || indice == _ultimaLineaResaltada) return;
    _ultimaLineaResaltada = indice;
    if (!_scrollController.hasClients) return;
    final offset = (indice * _alturaPorLinea) - 180;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final cancion = player.currentSong;
    _asegurarCargaParaCancion(cancion);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.paper),
          tooltip: "Cerrar",
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          cancion?.title ?? "Letra",
          style: AppTheme.subheading.copyWith(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: cancion == null
          ? const EstadoVacio(
              icono: Icons.lyrics_outlined,
              mensaje: "No hay ninguna canción sonando. Reproducí algo y "
                  "volvé acá para ver la letra.",
            )
          : FutureBuilder<Lyrics>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final letra = snapshot.data ?? Lyrics.vacia;

                if (!letra.hayAlgo) {
                  return const EstadoVacio(
                    icono: Icons.lyrics_outlined,
                    mensaje: 'No se encontró la letra de esta canción. No '
                        'todas las tienen publicada.',
                  );
                }

                if (letra.estaSincronizada) {
                  return _construirLetraSincronizada(letra.lineas!);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    letra.textoPlano!,
                    style: AppTheme.body.copyWith(fontSize: 16, height: 1.7),
                  ),
                );
              },
            ),
    );
  }

  Widget _construirLetraSincronizada(List<LineaLetra> lineas) {
    return StreamBuilder<Duration>(
      // player.positionStream (just_audio) da actualizaciones fluidas,
      // a diferencia de playbackState que solo cambia en eventos
      // puntuales — necesario para que el resaltado se sienta en vivo.
      stream: audioHandler.player.positionStream,
      builder: (context, snapshot) {
        final posicion = snapshot.data ?? Duration.zero;
        final indiceActual = _indiceLineaActual(lineas, posicion);

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollALinea(indiceActual));

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 140, horizontal: 28),
          itemCount: lineas.length,
          itemBuilder: (context, index) {
            final activa = index == indiceActual;
            return GestureDetector(
              onTap: () => audioHandler.seek(lineas[index].tiempo),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: activa ? AppTheme.paper : AppTheme.faintInk,
                    fontSize: activa ? 22 : 18,
                    fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                    height: 1.4,
                  ),
                  child: Text(lineas[index].texto),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
