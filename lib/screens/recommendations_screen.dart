import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/song_cover.dart';

class RecommendationsScreen extends StatelessWidget {
  final List<Song> allSongs;

  /// Igual que en StatisticsScreen: esta pantalla se inserta directo
  /// dentro de PantallaPrincipal (no vía Navigator.push), así que
  /// Navigator.pop no tiene ninguna ruta real que sacar — vacía el
  /// Navigator entero y deja la pantalla en negro. [onVolver] es lo
  /// que realmente hay que ejecutar (volver a Inicio).
  final VoidCallback? onVolver;

  const RecommendationsScreen(
      {super.key, required this.allSongs, this.onVolver});

  void _volver(BuildContext context) {
    if (onVolver != null) {
      onVolver!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final recommendations = player.getRecommendations(allSongs);

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title: Text('Recomendado para ti',
            style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.paper),
          tooltip: "Volver",
          onPressed: () => _volver(context),
        ),
      ),
      body: recommendations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Escucha más música para obtener recomendaciones',
                  style: AppTheme.body,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final song = recommendations[index];
                final esFavorita = playlistProvider.isFavorite(song.id);
                return ListTile(
                  leading: SongCover(
                    title: song.title,
                    artist: song.artist,
                    url: song.url,
                    coverUrlDirecto: song.coverUrl,
                    size: 44,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  title: Text(song.title,
                      style: AppTheme.body.copyWith(
                          color: AppTheme.paper, fontWeight: FontWeight.w600)),
                  subtitle: Text(song.artist, style: AppTheme.small),
                  trailing: Icon(
                    esFavorita ? Icons.favorite : Icons.favorite_border,
                    color: esFavorita ? AppTheme.amber : AppTheme.mutedInk,
                  ),
                  onTap: () {
                    player.playSong(song, recommendations, index);
                    _volver(context);
                  },
                );
              },
            ),
    );
  }
}
