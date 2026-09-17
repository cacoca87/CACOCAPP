import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/song_cover.dart';

/// Muestra la cola de reproducción actual (la playlist que se está
/// escuchando ahora, no una playlist guardada) con la canción en
/// curso resaltada, y deja saltar a cualquier otra con un toque.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final ScrollController _scroll = ScrollController();

  /// Alto aproximado de cada fila. No hace falta que sea exacto: solo
  /// sirve para dejar la canción en curso a la vista al abrir.
  static const double _altoAproximadoDeFila = 72;

  @override
  void initState() {
    super.initState();
    // La cola puede tener cientos de canciones. Sin esto, abrir "Cola
    // de reproducción" mientras suena la número 200 mostraba el
    // principio de la lista y había que buscarla a mano.
    WidgetsBinding.instance.addPostFrameCallback((_) => _irALaActual());
  }

  void _irALaActual() {
    if (!mounted || !_scroll.hasClients) return;
    final indice = context.read<PlayerProvider>().currentIndex;
    if (indice <= 2) return;
    // Se deja un par de filas arriba para que se vea de dónde viene.
    final destino = (indice - 2) * _altoAproximadoDeFila;
    _scroll.jumpTo(destino.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
              controller: _scroll,
              itemCount: cola.length,
              itemBuilder: (context, index) {
                final cancion = cola[index];
                final esActual = index == indiceActual;

                // El color de "esta es la que suena" va en el propio
                // ListTile y no en un Container alrededor: envuelto, el
                // destello al tocar la fila queda TAPADO y no se ve.
                return Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    tileColor:
                        esActual ? AppTheme.surfaceRaised : Colors.transparent,
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
