import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_effects_provider.dart';
import '../styles/app_theme.dart';

String _formatearFrecuencia(int hz) {
  if (hz >= 1000) {
    final khz = hz / 1000;
    return '${khz % 1 == 0 ? khz.toInt() : khz.toStringAsFixed(1)}kHz';
  }
  return '${hz}Hz';
}

/// Panel de "Audio": ecualizador + realce de graves + realce de
/// volumen. Aplica a toda la música de la app (Drive/R2, Jamendo,
/// descargas) sin importar de dónde vino la canción actual -- son
/// efectos que Android aplica sobre la sesión de audio, no sobre el
/// archivo puntual. No afecta al video de YouTube (motor de audio
/// distinto, dentro del WebView).
void mostrarPanelDeAudio(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _PanelDeAudio(),
  );
}

class _PanelDeAudio extends StatelessWidget {
  const _PanelDeAudio();

  @override
  Widget build(BuildContext context) {
    final fx = context.watch<AudioEffectsProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        Widget contenido;
        if (fx.cargando) {
          contenido = const Center(
              child: CircularProgressIndicator(color: AppTheme.amber));
        } else if (!fx.disponible) {
          contenido = Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tu dispositivo no soporta ecualizador. Esto depende del '
                'fabricante del celular, no de la app.',
                style: AppTheme.body,
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          contenido = ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text("Audio", style: AppTheme.heading.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                "Se aplica a toda tu música (Drive, Jamendo, descargas)",
                style: AppTheme.small,
              ),
              const SizedBox(height: 20),
              _SeccionConSwitch(
                titulo: "Ecualizador",
                activo: fx.eqActivo,
                onCambiar: (_) => fx.toggleEcualizador(),
                child: SizedBox(
                  height: 180,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: fx.info.bandas.map((banda) {
                      return _BandaSlider(
                        etiqueta: _formatearFrecuencia(banda.frecuenciaHz),
                        valor: fx.nivelBanda(banda.indice),
                        min: fx.info.nivelMinimo,
                        max: fx.info.nivelMaximo,
                        habilitado: fx.eqActivo,
                        onCambiar: (v) => fx.setNivelBanda(banda.indice, v),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (fx.info.bassBoostDisponible) ...[
                const SizedBox(height: 24),
                _SeccionConSwitch(
                  titulo: "Realzar graves",
                  activo: fx.gravesActivo,
                  onCambiar: (_) => fx.toggleGraves(),
                  child: Slider(
                    value: fx.fuerzaGraves.toDouble(),
                    min: 0,
                    max: 1000,
                    activeColor: AppTheme.amber,
                    onChanged: fx.gravesActivo
                        ? (v) => fx.setFuerzaGraves(v.toInt())
                        : null,
                  ),
                ),
              ],
              if (fx.info.realceVolumenDisponible) ...[
                const SizedBox(height: 8),
                _SeccionConSwitch(
                  titulo: "Realzar volumen bajo",
                  activo: fx.volumenActivo,
                  onCambiar: (_) => fx.toggleVolumen(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Slider(
                        value: fx.gananciaVolumen.toDouble(),
                        min: 0,
                        max: 1000,
                        activeColor: AppTheme.amber,
                        onChanged: fx.volumenActivo
                            ? (v) => fx.setGananciaVolumen(v.toInt())
                            : null,
                      ),
                      Text(
                        "Útil para canciones que quedaron grabadas muy flojas -- "
                        "no reemplaza tener buenos archivos de origen.",
                        style: AppTheme.small,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }

        return SafeArea(top: false, child: contenido);
      },
    );
  }
}

class _SeccionConSwitch extends StatelessWidget {
  final String titulo;
  final bool activo;
  final ValueChanged<bool> onCambiar;
  final Widget child;

  const _SeccionConSwitch({
    required this.titulo,
    required this.activo,
    required this.onCambiar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titulo,
              style: AppTheme.subheading.copyWith(fontSize: 15),
            ),
            Switch(
              value: activo,
              activeThumbColor: AppTheme.amber,
              onChanged: onCambiar,
            ),
          ],
        ),
        child,
      ],
    );
  }
}

class _BandaSlider extends StatelessWidget {
  final String etiqueta;
  final int valor;
  final int min;
  final int max;
  final bool habilitado;
  final ValueChanged<int> onCambiar;

  const _BandaSlider({
    required this.etiqueta,
    required this.valor,
    required this.min,
    required this.max,
    required this.habilitado,
    required this.onCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: valor.toDouble().clamp(min.toDouble(), max.toDouble()),
              min: min.toDouble(),
              max: max.toDouble(),
              activeColor: AppTheme.amber,
              onChanged: habilitado ? (v) => onCambiar(v.toInt()) : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(etiqueta, style: AppTheme.small.copyWith(fontSize: 10)),
      ],
    );
  }
}
