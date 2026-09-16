import 'package:flutter/material.dart';
import '../models/song.dart';
import '../styles/app_theme.dart';
import 'estado_vacio.dart';
import 'song_cover.dart';

/// Grilla tipo Spotify usada para "Playlists", "Artistas" y "Álbumes".
/// Extraído de `pantalla_principal.dart` (donde vivía como
/// `_construirVistaSpotifyGrid`). Igual que en `CarruselPlaylists`: el
/// tap ya no hace `setState` directo, avisa por [onSeleccionarElemento].
class VistaSpotifyGrid extends StatelessWidget {
  final String titulo;

  /// Etiqueta en singular que va debajo del nombre de cada tarjeta.
  /// Antes se calculaba sacándole la última letra a [titulo], lo que
  /// servía para "Playlists"/"Artistas" pero dejaba "Álbumes" como
  /// "Álbume" en pantalla. Se pasa explícita para que cada sección
  /// diga lo que corresponde.
  final String tituloSingular;

  final List<String> elementos;
  final IconData icono;
  final bool esPantallaPequena;
  final Map<String, Song>? representativas;
  final ValueChanged<String> onSeleccionarElemento;

  const VistaSpotifyGrid({
    super.key,
    required this.titulo,
    required this.tituloSingular,
    required this.elementos,
    required this.icono,
    required this.esPantallaPequena,
    required this.onSeleccionarElemento,
    this.representativas,
  });

  @override
  Widget build(BuildContext context) {
    if (elementos.isEmpty) {
      return EstadoVacio(
        icono: Icons.library_music_outlined,
        mensaje: "No hay $titulo disponibles todavía.",
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style:
              AppTheme.heading.copyWith(fontSize: esPantallaPequena ? 22 : 26),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: esPantallaPequena ? 2 : 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: elementos.length,
            itemBuilder: (context, index) {
              final nombreItem = elementos[index];
              return InkWell(
                onTap: () => onSeleccionarElemento(nombreItem),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(builder: (context, constraints) {
                            final representativa = representativas?[nombreItem];
                            final tamCelda = constraints.maxWidth;
                            if (representativa != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SongCover(
                                  title: representativa.title,
                                  artist: representativa.artist,
                                  url: representativa.url,
                                  coverUrlDirecto: representativa.coverUrl,
                                  size: tamCelda,
                                  borderRadius: BorderRadius.zero,
                                ),
                              );
                            }
                            return Container(
                              decoration: AppTheme.gradientCard(
                                  AppTheme.gradientePara(nombreItem)),
                              child: Center(
                                child: Icon(
                                  icono,
                                  size: esPantallaPequena ? 40 : 55,
                                  color: AppTheme.paper.withValues(alpha: 0.92),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        nombreItem,
                        style: AppTheme.body.copyWith(
                            color: AppTheme.paper,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tituloSingular,
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
