import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/boton_volver.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/song_cover.dart';
import '../widgets/song_options_menu.dart';

class RecommendationsScreen extends StatelessWidget {
  final List<Song> allSongs;

  /// Igual que en StatisticsScreen: esta pantalla se inserta directo
  /// dentro de PantallaPrincipal (no vía Navigator.push), así que
  /// Navigator.pop no tiene ninguna ruta real que sacar — vacía el
  /// Navigator entero y deja la pantalla en negro. [onVolver] es lo
  /// que realmente hay que ejecutar (volver a Inicio). La explicación
  /// completa vive en `widgets/boton_volver.dart`.
  final VoidCallback? onVolver;

  const RecommendationsScreen(
      {super.key, required this.allSongs, this.onVolver});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final recommendations = player.getRecommendations(allSongs);

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        title: Text('Recomendado para ti',
            style: AppTheme.subheading.copyWith(fontSize: 18)),
        leading: BotonVolver(onVolver: onVolver),
      ),
      body: recommendations.isEmpty
          ? const EstadoVacio(
              icono: Icons.auto_awesome_rounded,
              mensaje: 'Escuchá más música y acá van a aparecer canciones '
                  'parecidas a las que más ponés.',
            )
          : ListView.builder(
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final song = recommendations[index];
                return ListTile(
                  leading: SongCover(
                    title: song.title,
                    artist: song.artist,
                    url: song.url,
                    coverUrlDirecto: song.coverUrl,
                    size: 44,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  // Una sola línea, igual que en el resto de las listas:
                  // sin esto un título largo partía la fila en dos y la
                  // lista quedaba despareja. Era la única lista de la
                  // app a la que le faltaba.
                  title: Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                          color: AppTheme.paper, fontWeight: FontWeight.w600)),
                  subtitle: Text(song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.small),
                  // Antes acá había un corazón que era solo un ícono: se
                  // veía como un botón pero no se podía tocar. Ahora es
                  // el mismo menú que usan todas las listas de la app,
                  // desde donde sí se puede marcar como favorita.
                  trailing: SongOptionsMenu(
                    cancion: song,
                    // No es una playlist: ver la nota en `SongOptionsMenu`.
                    bibliotecaSeleccionada: null,
                  ),
                  onTap: () {
                    player.playSong(song, recommendations, index);
                    volverAtras(context, onVolver);
                  },
                );
              },
            ),
    );
  }
}
