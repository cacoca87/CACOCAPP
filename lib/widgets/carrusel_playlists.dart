import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/playlist.dart';
import '../utils/plural.dart';
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
    // Igual que en `carrusel_canciones.dart`: el alto que se reserva
    // para el nombre y la cantidad de canciones crece con la escala de
    // letra del sistema. Acá el número fijo era todavía más justo (56)
    // y se desbordaba antes.
    final escala = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
    final altoTexto = 56 * escala;
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
            height: ancho + altoTexto,
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
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSeleccionarPlaylist(playlist.name);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Flexible + cuadrada, por el mismo motivo que
                          // en `carrusel_canciones.dart`: la tapa cede
                          // el espacio que necesite el texto, así el
                          // desbordado es imposible por como está
                          // armado y no por haber acertado un número.
                          Flexible(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: AppTheme.gradientCard(
                                    AppTheme.gradientePara(playlist.name)),
                                child: Center(
                                  child: Icon(
                                    Icons.playlist_play_rounded,
                                    size: esPantallaPequena ? 40 : 50,
                                    color:
                                        AppTheme.paper.withValues(alpha: 0.92),
                                  ),
                                ),
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
                          Text(contarCanciones(playlist.songs.length),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
