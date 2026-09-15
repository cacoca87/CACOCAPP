import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../main.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/artwork_service.dart';
import '../services/id3_cover_service.dart';
import '../services/share_service.dart';
import '../styles/app_theme.dart';
import '../widgets/audio_effects_sheet.dart';
import '../widgets/song_cover.dart';
import 'queue_screen.dart';
import 'lyrics_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Color? _colorDominante;
  String? _songIdColorCargado;
  // Mientras el usuario arrastra el slider, se muestra ESTE valor en
  // vez del que viene del stream -- si no, cada tick de
  // `positionStream` (cada ~200ms) pisaría el arrastre a mitad de
  // camino y el slider "pelearía" contra el dedo.
  double? _valorMientrasArrastra;

  Future<ImageProvider?> _resolverImagenPortada(Song song) async {
    if (song.url.isNotEmpty) {
      final embebida =
          await Id3CoverService.instance.getEmbeddedCover(song.url);
      if (embebida != null) return MemoryImage(embebida);
    }
    final url =
        await ArtworkService.instance.getCoverUrl(song.title, song.artist);
    if (url != null) return NetworkImage(url);
    return null;
  }

  Future<void> _actualizarColorDominante(Song song) async {
    if (_songIdColorCargado == song.id) return;
    _songIdColorCargado = song.id;
    try {
      final imagen = await _resolverImagenPortada(song);
      if (imagen == null) return;

      final paleta = await PaletteGenerator.fromImageProvider(imagen,
          maximumColorCount: 16);
      final color = paleta.dominantColor?.color ??
          paleta.vibrantColor?.color ??
          paleta.mutedColor?.color;
      if (color == null) return;

      if (!mounted || _songIdColorCargado != song.id) return;
      setState(() => _colorDominante = color);
    } catch (_) {
      // Si falla, mantenemos el color por defecto sin romper la app.
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Widget _buildControlButton({
    required IconData icon,
    double size = 28,
    Color? color,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, size: size, color: color ?? AppTheme.paper),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final mediaItem = mediaSnapshot.data;
        if (mediaItem == null) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppTheme.ink,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
              backgroundColor: AppTheme.ink,
              appBar: AppBar(backgroundColor: Colors.transparent),
              body: Center(
                child: Text("No hay canción reproduciéndose",
                    style: AppTheme.body),
              ),
            ),
          );
        }

        // Obtenemos la canción actual del provider de forma segura escuchando sin mutar el build state de golpe
        final cancionActual =
            context.select<PlayerProvider, Song?>((p) => p.currentSong);
        if (cancionActual != null) {
          // Usamos addPostFrameCallback para evitar conflictos de setState durante la fase de construcción
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _actualizarColorDominante(cancionActual);
          });
        }
        final bgColor = _colorDominante ?? AppTheme.amber;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppTheme.ink,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: AppTheme.ink,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppTheme.paper),
                tooltip: "Minimizar",
                onPressed: () => Navigator.pop(context),
              ),
              title: Text("REPRODUCIENDO",
                  style: AppTheme.caption
                      .copyWith(letterSpacing: 2.5, color: AppTheme.paper)),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: "Audio (ecualizador)",
                  icon: const Icon(Icons.graphic_eq_rounded,
                      color: AppTheme.paper),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    mostrarPanelDeAudio(context);
                  },
                ),
                IconButton(
                  tooltip: "Letra",
                  icon:
                      const Icon(Icons.lyrics_outlined, color: AppTheme.paper),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LyricsScreen()),
                    );
                  },
                ),
                IconButton(
                  tooltip: "Cola de reproducción",
                  icon: const Icon(Icons.queue_music_rounded,
                      color: AppTheme.paper),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QueueScreen()),
                    );
                  },
                ),
                Builder(builder: (context) {
                  final songId = context.select<PlayerProvider, String?>(
                      (p) => p.currentSong?.id);
                  final playlistProvider = context.watch<PlaylistProvider>();
                  final esFavorita =
                      songId != null && playlistProvider.isFavorite(songId);
                  return IconButton(
                    icon: Icon(
                      esFavorita ? Icons.favorite : Icons.favorite_border,
                      color: esFavorita ? AppTheme.amber : AppTheme.paper,
                    ),
                    tooltip: esFavorita
                        ? "Quitar de favoritos"
                        : "Agregar a favoritos",
                    onPressed: songId == null
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            context
                                .read<PlaylistProvider>()
                                .toggleFavorite(songId);
                          },
                  );
                }),
                Builder(builder: (context) {
                  final playerProvider = context.watch<PlayerProvider>();
                  final activo = playerProvider.sleepTimerActivo;
                  return PopupMenuButton<int>(
                    tooltip: "Temporizador de sueño",
                    icon: Icon(
                      activo ? Icons.bedtime : Icons.bedtime_outlined,
                      color: activo ? AppTheme.amber : AppTheme.paper,
                    ),
                    color: AppTheme.surfaceRaised,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (minutos) {
                      final provider = context.read<PlayerProvider>();
                      if (minutos == -1) {
                        provider.cancelarTemporizadorDeSueno();
                      } else {
                        provider.activarTemporizadorDeSueno(
                            Duration(minutes: minutos));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("La música se pausará en $minutos min"),
                            backgroundColor: AppTheme.amber,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      if (activo)
                        PopupMenuItem(
                          value: -1,
                          child: Text(
                            "Cancelar (quedan ${playerProvider.sleepTimerMinutosRestantes} min)",
                            style: AppTheme.body
                                .copyWith(color: AppTheme.danger, fontSize: 13),
                          ),
                        ),
                      if (activo) const PopupMenuDivider(),
                      for (final min in [10, 15, 30, 45, 60])
                        PopupMenuItem(
                          value: min,
                          child: Text("$min minutos",
                              style: AppTheme.body.copyWith(
                                  color: AppTheme.paper, fontSize: 13)),
                        ),
                    ],
                  );
                }),
                Builder(builder: (context) {
                  final cancion = context
                      .select<PlayerProvider, Song?>((p) => p.currentSong);
                  return PopupMenuButton<String>(
                    tooltip: "Más opciones",
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppTheme.paper),
                    color: AppTheme.surfaceRaised,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (accion) {
                      if (accion == "compartir" && cancion != null) {
                        HapticFeedback.selectionClick();
                        ShareService.instance.compartirCancion(
                          titulo: cancion.title,
                          artista: cancion.artist,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "compartir",
                        enabled: cancion != null,
                        child: Row(
                          children: [
                            const Icon(Icons.share_rounded,
                                color: AppTheme.paper, size: 18),
                            const SizedBox(width: 10),
                            Text("Compartir",
                                style: AppTheme.body.copyWith(
                                    color: AppTheme.paper, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(width: 4),
              ],
            ),
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.3,
                  colors: [
                    bgColor.withValues(alpha: 0.55),
                    AppTheme.ink,
                  ],
                  stops: const [0.0, 0.75],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onDoubleTap: () {
                          audioHandler.seek(audioHandler.player.position +
                              const Duration(seconds: 10));
                        },
                        onDoubleTapDown: (details) {
                          final size = MediaQuery.of(context).size;
                          if (details.globalPosition.dx < size.width / 2) {
                            audioHandler.seek(audioHandler.player.position -
                                const Duration(seconds: 10));
                          }
                        },
                        child: Builder(builder: (context) {
                          return Hero(
                            tag: 'caratula_${mediaItem.id}',
                            child: SongCover(
                              title: mediaItem.title,
                              artist: mediaItem.artist ?? '',
                              url: cancionActual?.url ?? '',
                              coverUrlDirecto: cancionActual?.coverUrl ?? '',
                              size: 280,
                              borderRadius: BorderRadius.circular(16),
                              showShadow: true,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        mediaItem.title,
                        style: AppTheme.heading.copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mediaItem.artist ?? "CACOCAPP",
                        style: AppTheme.body.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Antes se leía `playbackState.updatePosition`, que solo
                      // se actualiza en eventos discretos (play/pausa/seek) --
                      // por eso la barra quedaba "congelada" mientras la
                      // canción sonaba normalmente. `positionStream` de
                      // just_audio sí emite continuamente durante la
                      // reproducción, así la barra avanza en vivo de verdad.
                      StreamBuilder<Duration>(
                        stream: audioHandler.player.positionStream,
                        initialData: audioHandler.player.position,
                        builder: (context, positionSnapshot) {
                          final totalDuration =
                              mediaItem.duration ?? const Duration(minutes: 3);
                          double maxVal =
                              totalDuration.inMilliseconds.toDouble();
                          if (maxVal <= 0) maxVal = 1.0;

                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          final valorReal = position.inMilliseconds
                              .toDouble()
                              .clamp(0.0, maxVal);
                          // Mientras se arrastra el slider, se ignora el valor
                          // del stream para que no "pelee" contra el dedo.
                          final currentVal =
                              _valorMientrasArrastra ?? valorReal;

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  activeTrackColor: AppTheme.amber,
                                  inactiveTrackColor: const Color(0x33F2EDE6),
                                  thumbColor: AppTheme.paper,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 16),
                                  overlayColor:
                                      AppTheme.amber.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: currentVal,
                                  min: 0.0,
                                  max: maxVal,
                                  onChangeStart: (value) => setState(
                                      () => _valorMientrasArrastra = value),
                                  onChanged: (value) => setState(
                                      () => _valorMientrasArrastra = value),
                                  onChangeEnd: (value) {
                                    audioHandler.seek(
                                        Duration(milliseconds: value.toInt()));
                                    setState(
                                        () => _valorMientrasArrastra = null);
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(Duration(
                                          milliseconds: currentVal.toInt())),
                                      style: AppTheme.small,
                                    ),
                                    Text(_formatDuration(totalDuration),
                                        style: AppTheme.small),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Consumer<PlayerProvider>(
                        builder: (context, playerProvider, _) {
                          final repeatIcon =
                              switch (playerProvider.repeatMode) {
                            2 => Icons.repeat_one_rounded,
                            _ => Icons.repeat_rounded,
                          };
                          final repeatActivo = playerProvider.repeatMode != 0;
                          final repeatTooltip =
                              switch (playerProvider.repeatMode) {
                            1 => "Repetir todo (activado)",
                            2 => "Repetir una canción (activado)",
                            _ => "Repetir (desactivado)",
                          };

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildControlButton(
                                icon: Icons.shuffle_rounded,
                                size: 26,
                                color: playerProvider.isShuffleEnabled
                                    ? AppTheme.amber
                                    : AppTheme.mutedInk,
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  playerProvider.toggleShuffle();
                                },
                                tooltip: playerProvider.isShuffleEnabled
                                    ? "Aleatorio (activado)"
                                    : "Aleatorio (desactivado)",
                              ),
                              _buildControlButton(
                                icon: Icons.skip_previous_rounded,
                                size: 40,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  audioHandler.skipToPrevious();
                                },
                                tooltip: "Anterior",
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: bgColor.withValues(alpha: 0.35),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: StreamBuilder<PlaybackState>(
                                  stream: audioHandler.playbackState,
                                  builder: (context, snapshot) {
                                    final playing =
                                        snapshot.data?.playing ?? false;
                                    return IconButton(
                                      icon: Icon(
                                        playing
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_filled,
                                        size: 72,
                                        color: AppTheme.amber,
                                      ),
                                      tooltip:
                                          playing ? "Pausar" : "Reproducir",
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        if (playing) {
                                          audioHandler.pause();
                                        } else {
                                          audioHandler.play();
                                        }
                                      },
                                      constraints: const BoxConstraints(),
                                    );
                                  },
                                ),
                              ),
                              _buildControlButton(
                                icon: Icons.skip_next_rounded,
                                size: 40,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  audioHandler.skipToNext();
                                },
                                tooltip: "Siguiente",
                              ),
                              _buildControlButton(
                                icon: repeatIcon,
                                size: 26,
                                color: repeatActivo
                                    ? AppTheme.amber
                                    : AppTheme.mutedInk,
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  playerProvider.toggleRepeat();
                                },
                                tooltip: repeatTooltip,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
