import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../styles/app_theme.dart';
import 'song_cover.dart';
import 'tarjeta_presionable.dart';

/// Fila horizontal de canciones con carátula, título y artista (ej.
/// "Escuchado recientemente", "Tus favoritas"). Extraído de
/// `pantalla_principal.dart` (donde vivía como `_construirCarruselCanciones`)
/// porque no depende de nada del estado de esa pantalla: recibe todo
/// por constructor.
class CarruselCanciones extends StatelessWidget {
  final String titulo;
  final List<Song> canciones;
  final PlayerProvider player;
  final bool esPantallaPequena;
  final VoidCallback onVerTodo;

  const CarruselCanciones({
    super.key,
    required this.titulo,
    required this.canciones,
    required this.player,
    required this.esPantallaPequena,
    required this.onVerTodo,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = esPantallaPequena ? 128.0 : 160.0;
    // Cuánto alto se reserva DEBAJO de la tapa, para el título y el
    // artista.
    //
    // Crece con la escala de letra del sistema en vez de ser un número
    // fijo. Antes eran 66 píxeles a secas, calculados con la letra
    // normal: con la letra grande --que es lo que traen de fábrica
    // varios Samsung, y algo que mucha gente sube a mano-- los dos
    // renglones dejaban de entrar y la fila salía con las rayas
    // amarillas y negras de "desbordado", justo en la pantalla de
    // Inicio, que es la primera que se ve al abrir la app. Mismo motivo
    // que el alto de la barra en `mini_player.dart`.
    final escala = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
    final altoTexto = 66 * escala;
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
              itemCount: canciones.length,
              itemBuilder: (context, index) {
                final cancion = canciones[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: ancho,
                    child: TarjetaPresionable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        player.playSong(cancion, canciones, index);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SongCover(
                            title: cancion.title,
                            artist: cancion.artist,
                            url: cancion.url,
                            coverUrlDirecto: cancion.coverUrl,
                            size: ancho,
                            borderRadius: BorderRadius.circular(8),
                            showShadow: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cancion.title,
                            style: AppTheme.body.copyWith(
                                color: AppTheme.paper,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cancion.artist,
                            style: AppTheme.small,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
