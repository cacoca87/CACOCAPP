import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../providers/online_video_provider.dart';
import '../styles/app_theme.dart';

/// Muestra el video de YouTube que esté sonando (si hay uno), en
/// pantalla completa o como burbuja flotante -- según
/// `OnlineVideoProvider.minimizado`. Se coloca directo en el `Stack`
/// de `PantallaPrincipal`, NO como una ruta de `Navigator`: así el
/// video sigue sonando sin importar qué sección esté mirando el
/// usuario, en vez de destruirse apenas se toca "atrás" (que era el
/// problema reportado).
class OnlineVideoOverlay extends StatelessWidget {
  const OnlineVideoOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineVideoProvider>();
    if (!provider.hayVideo) return const SizedBox.shrink();

    return provider.minimizado ? const _BurbujaFlotante() : const _VideoPantallaCompleta();
  }
}

class _VideoPantallaCompleta extends StatelessWidget {
  const _VideoPantallaCompleta();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineVideoProvider>();
    final controller = provider.controller;
    if (controller == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: AppTheme.ink,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.paper, size: 28),
                      tooltip: "Minimizar",
                      onPressed: () => context.read<OnlineVideoProvider>().minimizar(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            provider.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body.copyWith(
                              color: AppTheme.paper,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            provider.autor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.small.copyWith(color: AppTheme.mutedInk),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.mutedInk, size: 22),
                      tooltip: "Cerrar",
                      onPressed: () => context.read<OnlineVideoProvider>().cerrar(),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: StreamBuilder<YoutubePlayerValue>(
                  stream: controller.stream,
                  builder: (context, snapshot) {
                    final valor = snapshot.data;
                    if (valor != null && valor.hasError) {
                      return Container(
                        color: AppTheme.ink,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          'YouTube no dejó reproducir este video acá '
                          '(código ${valor.error}). Probá con otro resultado.',
                          textAlign: TextAlign.center,
                          style: AppTheme.body.copyWith(color: AppTheme.mutedInk),
                        ),
                      );
                    }
                    return YoutubePlayer(controller: controller);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Tocá la flecha para minimizar y seguir escuchando mientras '
                  'usás el resto de la app -- se pausa solo si ponés a sonar '
                  'otra canción.',
                  textAlign: TextAlign.center,
                  style: AppTheme.small.copyWith(color: AppTheme.faintInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BurbujaFlotante extends StatelessWidget {
  const _BurbujaFlotante();

  static const double _ancho = 160;
  static const double _alto = 96;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineVideoProvider>();
    final controller = provider.controller;
    if (controller == null) return const SizedBox.shrink();

    return Positioned(
      right: 12,
      bottom: 96, // por encima del MiniPlayer, para no taparlo
      child: GestureDetector(
        onTap: () => context.read<OnlineVideoProvider>().expandir(),
        child: Container(
          width: _ancho,
          height: _alto,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.amber.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              SizedBox(
                width: _ancho,
                height: _alto,
                child: IgnorePointer(
                  // Los controles nativos de YouTube quedan demasiado
                  // chicos para tocarlos bien en este tamaño -- se
                  // ignoran los toques acá y se usa el tap de afuera
                  // para expandir (y el botón de cerrar aparte).
                  child: YoutubePlayer(controller: controller),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => context.read<OnlineVideoProvider>().cerrar(),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
