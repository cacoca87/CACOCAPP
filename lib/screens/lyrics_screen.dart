import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';
import '../styles/app_theme.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/letra_sincronizada.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  Future<Lyrics>? _future;
  String? _songIdCargado;

  /// Si la canción actual cambió desde la última vez, dispara una
  /// nueva búsqueda. Se llama desde build() — al mutar los campos acá
  /// (sin setState) el propio build ya refleja el cambio, así que no
  /// hace falta nada más.
  void _asegurarCargaParaCancion(Song? song) {
    if (song == null || _songIdCargado == song.id) return;
    _songIdCargado = song.id;
    _future = LyricsService.instance.getLyrics(
      title: song.title,
      artist: song.artist,
      urlCancion: song.url,
      // La duración real es lo que separa esta canción de otra que se
      // llama igual. Sin esto, la app llegó a mostrar una letra en
      // inglés de 2:47 para una canción en español de 4:13.
      duracion: audioHandler.player.duration,
    );
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
                  // El resaltado y el desplazamiento viven en
                  // `LetraSincronizada`, compartido con el panel de
                  // abajo del video de YouTube para que las dos
                  // pantallas se comporten igual.
                  return LetraSincronizada(
                    lineas: letra.lineas!,
                    // positionStream (just_audio) da actualizaciones
                    // fluidas, a diferencia de playbackState que solo
                    // cambia en eventos puntuales — necesario para que
                    // el resaltado se sienta en vivo.
                    posicion: audioHandler.player.positionStream,
                    onTocarLinea: audioHandler.seek,
                  );
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
}
