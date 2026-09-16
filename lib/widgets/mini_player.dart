import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../styles/app_theme.dart';
import '../utils/transiciones.dart';
import 'song_cover.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  /// Alto de la barra, sin contar la línea de progreso de arriba.
  ///
  /// Crece con la escala de texto del sistema en vez de ser un número
  /// fijo. Antes eran 65 píxeles a secas, y en un celular con la letra
  /// más grande -- que es la configuración de fábrica de varios Samsung,
  /// y algo que mucha gente sube a mano -- el título y el artista no
  /// entraban y quedaban cortados. Esa es la clase de falla que anda
  /// perfecto en el celular donde se programó y se rompe en el de otro.
  ///
  /// Se topea en 1.6 para que, con escalas enormes, la barra no se coma
  /// media pantalla: el título completo siempre está en el reproductor
  /// grande, que es donde hay lugar de sobra.
  static double altoBarra(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    return 65 * escala;
  }

  /// Alto total, incluyendo la línea de progreso. Lo usa
  /// `online_video_overlay.dart` para ubicar la barra del video justo
  /// encima; tienen que salir del mismo lugar o una se le monta a la
  /// otra.
  static double altoTotal(BuildContext context) => altoBarra(context) + 2;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, rutaDesdeAbajo(const PlayerScreen()));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LineaDeProgreso(),
          Container(
            height: altoBarra(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'caratula_${song.id}',
                  child: SongCover(
                    title: song.title,
                    artist: song.artist,
                    url: song.url,
                    coverUrlDirecto: song.coverUrl,
                    size: 45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        style: AppTheme.body.copyWith(
                            color: AppTheme.paper,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: AppTheme.small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppTheme.paper,
                    size: 26,
                  ),
                  tooltip: player.isPlaying ? "Pausar" : "Reproducir",
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    player.togglePlayPause();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded,
                      color: AppTheme.paper, size: 24),
                  tooltip: "Siguiente",
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    player.playNext();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea finísima de progreso arriba del mini reproductor, como la que
/// tienen Spotify y YouTube Music. Deja ver de un vistazo cuánto falta
/// de la canción sin abrir el reproductor completo.
///
/// Cuando no hay duración conocida todavía (recién arrancando, o un
/// stream sin duración) queda en cero, o sea una línea del color del
/// borde -- que es justo lo que había antes acá, así que no se ve peor
/// en ningún caso.
class _LineaDeProgreso extends StatelessWidget {
  const _LineaDeProgreso();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioHandler.player.positionStream,
      builder: (context, snapshot) {
        final duracion = audioHandler.player.duration;
        final posicion = snapshot.data ?? Duration.zero;
        final progreso = (duracion == null || duracion.inMilliseconds <= 0)
            ? 0.0
            : (posicion.inMilliseconds / duracion.inMilliseconds)
                .clamp(0.0, 1.0);
        return LinearProgressIndicator(
          value: progreso,
          minHeight: 2,
          backgroundColor: AppTheme.hairline,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.amber),
        );
      },
    );
  }
}
