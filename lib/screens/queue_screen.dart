import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/song_cover.dart';

/// Muestra la cola de reproducción actual (la playlist que se está
/// escuchando ahora, no una playlist guardada) con la canción en
/// curso resaltada, y deja saltar a cualquier otra con un toque.
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final cola = player.queue;
    final indiceActual = player.currentIndex;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        elevation: 0,
        title: Text("Cola de reproducción",
            style: AppTheme.subheading.copyWith(fontSize: 16)),
      ),
      body: cola.isEmpty
          ? const EstadoVacio(
              icono: Icons.queue_music_rounded,
              mensaje: "No hay ninguna cola activa. Poné a sonar una canción "
                  "y acá vas a ver qué sigue después.",
            )
          : ListView.builder(
              itemCount: cola.length,
              itemBuilder: (context, index) {
                final cancion = cola[index];
                final esActual = index == indiceActual;

                return Container(
                  color: esActual ? AppTheme.surfaceRaised : Colors.transparent,
                  child: ListTile(
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
                        color: esActual ? AppTheme.amber : AppTheme.paper,
                        fontWeight:
                            esActual ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      cancion.artist,
                      style: AppTheme.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: esActual
                        ? const Icon(Icons.equalizer_rounded,
                            color: AppTheme.amber, size: 20)
                        : Text("${index + 1}", style: AppTheme.small),
                    onTap: esActual
                        ? null
                        : () {
                            player.saltarAIndice(index);
                            Navigator.pop(context);
                          },
                  ),
                );
              },
            ),
    );
  }
}
