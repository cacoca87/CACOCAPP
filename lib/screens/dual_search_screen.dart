import 'dart:async';
import 'package:flutter/material.dart';
import '../services/youtube_service.dart';
import '../styles/app_theme.dart';
import '../utils/transiciones.dart';
import 'online_video_player_screen.dart';

class DualSearchScreen extends StatefulWidget {
  final VoidCallback? onVolver;

  const DualSearchScreen({super.key, this.onVolver});

  @override
  State<DualSearchScreen> createState() => _DualSearchScreenState();
}

class _DualSearchScreenState extends State<DualSearchScreen> {
  // Estos 2 campos son `static` a propósito: cuando el usuario navega
  // a otra sección (Inicio, Descubrir, etc.) esta pantalla se destruye
  // por completo y se crea una nueva la próxima vez que la abre --
  // eso es lo que hacía que la búsqueda y los resultados "desaparecieran"
  // al salir y volver a entrar. Como los `static` viven en la clase y
  // no en la instancia, sobreviven aunque el widget se destruya y se
  // vuelva a crear.
  static String _ultimaBusqueda = '';
  static List<YoutubeVideoResult> _ultimosResultados = [];

  late final TextEditingController _searchController =
      TextEditingController(text: _ultimaBusqueda);
  List<YoutubeVideoResult> _resultados = _ultimosResultados;
  bool _cargandoResultados = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _ultimaBusqueda = query;
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _ultimosResultados = [];
        _cargandoResultados = false;
      });
      return;
    }

    setState(() => _cargandoResultados = true);

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final resultados = await YoutubeService.instance.buscarVideos(query);
      if (mounted) {
        setState(() {
          _resultados = resultados;
          _ultimosResultados = resultados;
          _cargandoResultados = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.onVolver != null) {
          widget.onVolver!();
        }
      },
      child: Column(
        children: [
          // Cabecera con botón de retroceso y título modificado
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.paper, size: 18),
                tooltip: "Volver",
                onPressed: () {
                  if (widget.onVolver != null) {
                    widget.onVolver!();
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(
                "Búsqueda Online",
                style: AppTheme.heading.copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de búsqueda principal sin referencias explícitas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _searchController,
                style: AppTheme.body.copyWith(color: AppTheme.paper, fontSize: 14),
                onChanged: _onSearchChanged,
                onSubmitted: (query) {
                  if (query.trim().isNotEmpty) {
                    _onSearchChanged(query);
                  }
                },
                decoration: InputDecoration(
                  hintText: "Buscar música o videos en YouTube...",
                  hintStyle: AppTheme.body.copyWith(color: AppTheme.faintInk),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.amber),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.mutedInk),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Indicador de carga
          if (_cargandoResultados)
            const LinearProgressIndicator(color: AppTheme.amber),

          const SizedBox(height: 8),

          // Listado de resultados
          Expanded(
            child: _resultados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_library_outlined, size: 64, color: AppTheme.mutedInk),
                        const SizedBox(height: 12),
                        Text(
                          _cargandoResultados
                              ? "Buscando..."
                              : "Escribe algo para buscar música online",
                          style: AppTheme.body.copyWith(fontSize: 14, color: AppTheme.mutedInk),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _resultados.length,
                    itemBuilder: (context, index) {
                      final video = _resultados[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  video.thumbnailUrl,
                                  width: 75,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 75, height: 50, color: AppTheme.surfaceLight,
                                    child: const Icon(Icons.music_video, color: AppTheme.mutedInk),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                color: Colors.black87,
                                child: Text(
                                  video.lengthSeconds,
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body.copyWith(
                              color: AppTheme.paper,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            "${video.author} • ${video.viewCount}",
                            style: AppTheme.small.copyWith(fontSize: 11),
                          ),
                          // Se sacó el botón de descargar: sigue dependiendo
                          // de extraer el audio crudo de YouTube, lo mismo
                          // que rompía la reproducción antes de pasar al
                          // WebView -- ofrecerlo era prometer algo que
                          // fallaba seguido.
                          trailing: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.amber, size: 28),
                          // Se abre el reproductor oficial de YouTube embebido
                          // (WebView) en vez de intentar extraer el audio --
                          // por eso ya no hace falta esperar ninguna resolución
                          // de red antes de reproducir, y no puede quedar
                          // "trabado cargando" como pasaba antes.
                          onTap: () => Navigator.push(
                            context,
                            rutaDesdeAbajo(OnlineVideoPlayerScreen(
                              videoId: video.videoId,
                              title: video.title,
                              author: video.author,
                            )),
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
