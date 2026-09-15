import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../styles/app_theme.dart';
import '../utils/transiciones.dart';
import 'song_cover.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

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
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.hairline, width: 1)),
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
    );
  }
}
