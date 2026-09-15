import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/playlist.dart';
import '../styles/app_theme.dart';
import 'tarjeta_presionable.dart';

/// Fila horizontal de playlists. Extraído de `pantalla_principal.dart`
/// (donde vivía como `_construirCarruselPlaylists`). La única
/// diferencia con el original: en vez de hacer `setState` directo
/// sobre el estado de la pantalla al tocar una playlist, ahora avisa
/// mediante [onSeleccionarPlaylist] -- quien use este widget decide
/// qué hacer con esa selección.
class CarruselPlaylists extends StatelessWidget {
  final String titulo;
  final List<Playlist> playlists;
  final bool esPantallaPequena;
  final VoidCallback onVerTodo;
  final ValueChanged<String> onSeleccionarPlaylist;

  const CarruselPlaylists({
    super.key,
    required this.titulo,
    required this.playlists,
    required this.esPantallaPequena,
    required this.onVerTodo,
    required this.onSeleccionarPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = esPantallaPequena ? 128.0 : 160.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo,
                  style: AppTheme.subheading
                      .copyWith(fontSize: esPantallaPequena ? 16 : 18)),
              TextButton(
                onPressed: onVerTodo,
                child: Text("Ver todo",
                    style: AppTheme.caption.copyWith(fontSize: 12)),
              ),
            ],
          ),
          SizedBox(
            height: ancho + 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: ancho,
                    child: TarjetaPresionable(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSeleccionarPlaylist(playlist.name);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: ancho,
                            height: ancho,
                            decoration: AppTheme.gradientCard(
                                AppTheme.gradientePara(playlist.name)),
                            child: Center(
                              child: Icon(
                                Icons.playlist_play_rounded,
                                size: esPantallaPequena ? 40 : 50,
                                color: AppTheme.paper.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            playlist.name,
                            style: AppTheme.body.copyWith(
                                color: AppTheme.paper,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text("${playlist.songs.length} canciones",
                              style: AppTheme.small),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
