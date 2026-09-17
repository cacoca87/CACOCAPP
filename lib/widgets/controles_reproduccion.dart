import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// La fila de controles del reproductor grande: aleatorio, anterior,
/// play/pausa, siguiente y repetir.
///
/// SOBRE EL TAMAÑO DE LA ZONA DE TOQUE
///
/// Los de los costados --aleatorio y repetir-- llevan un ícono de 26
/// píxeles y el código decía explícitamente "sin nada alrededor". Se
/// midió esperando encontrar una zona tocable de 26, muy por debajo de
/// los 48 que se recomiendan para algo que se toca con el dedo.
///
/// **No era así**, y conviene que quede escrito para que nadie lo
/// vuelva a buscar acá: medidos, los cinco daban 48 de lado (y 72 el
/// grande). Material impone ese mínimo por su cuenta, aunque se le
/// pidan cero restricciones.
///
/// El mínimo se dejó escrito igual, porque ahora es una promesa de este
/// widget y no un efecto secundario de cómo esté configurado el tema:
/// si algún día alguien cambia esa opción del tema, acá no cambia nada.
///
/// Vive aparte y es pública para poder probarla: el reproductor entero
/// necesita el motor de audio del celular, que no arranca fuera de un
/// teléfono. Eso es lo que de verdad ganó este cambio -- once tests
/// sobre lo que sí puede fallar: que los cinco botones entren en el
/// ancho de un celular angosto, que cada uno avise lo suyo, y que los
/// tres modos de repetición se distingan entre sí.
class ControlesDeReproduccion extends StatelessWidget {
  /// Lo que ocupa el botón grande de play/pausa.
  static const double ladoDelBotonGrande = 72;

  /// La zona mínima que tiene que responder al toque en los demás.
  static const double zonaDeToqueMinima = 48;

  final bool aleatorioActivo;
  final VoidCallback onAleatorio;

  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  final bool sonando;
  final VoidCallback onPlayPausa;

  /// 0 = sin repetir, 1 = repetir todo, 2 = repetir esta canción.
  final int modoDeRepeticion;
  final VoidCallback onRepetir;

  /// El color del resplandor detrás del botón grande. Sale de la
  /// carátula que está sonando.
  final Color colorDelResplandor;

  const ControlesDeReproduccion({
    super.key,
    required this.aleatorioActivo,
    required this.onAleatorio,
    required this.onAnterior,
    required this.onSiguiente,
    required this.sonando,
    required this.onPlayPausa,
    required this.modoDeRepeticion,
    required this.onRepetir,
    required this.colorDelResplandor,
  });

  @override
  Widget build(BuildContext context) {
    final iconoDeRepeticion = switch (modoDeRepeticion) {
      2 => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
    final ayudaDeRepeticion = switch (modoDeRepeticion) {
      1 => 'Repetir todo (activado)',
      2 => 'Repetir una canción (activado)',
      _ => 'Repetir (desactivado)',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _boton(
          icono: Icons.shuffle_rounded,
          tamanoDelIcono: 26,
          color: aleatorioActivo ? AppTheme.amber : AppTheme.mutedInk,
          ayuda: aleatorioActivo
              ? 'Aleatorio (activado)'
              : 'Aleatorio (desactivado)',
          onTocar: onAleatorio,
        ),
        _boton(
          icono: Icons.skip_previous_rounded,
          tamanoDelIcono: 40,
          ayuda: 'Anterior',
          onTocar: onAnterior,
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorDelResplandor.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              sonando ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: ladoDelBotonGrande,
              color: AppTheme.amber,
            ),
            tooltip: sonando ? 'Pausar' : 'Reproducir',
            onPressed: onPlayPausa,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        _boton(
          icono: Icons.skip_next_rounded,
          tamanoDelIcono: 40,
          ayuda: 'Siguiente',
          onTocar: onSiguiente,
        ),
        _boton(
          icono: iconoDeRepeticion,
          tamanoDelIcono: 26,
          color: modoDeRepeticion != 0 ? AppTheme.amber : AppTheme.mutedInk,
          ayuda: ayudaDeRepeticion,
          onTocar: onRepetir,
        ),
      ],
    );
  }

  Widget _boton({
    required IconData icono,
    required double tamanoDelIcono,
    required String ayuda,
    required VoidCallback onTocar,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icono, size: tamanoDelIcono, color: color ?? AppTheme.paper),
      onPressed: onTocar,
      tooltip: ayuda,
      padding: EdgeInsets.zero,
      // El mínimo, escrito explícitamente. Medido, Material ya lo impone
      // por su cuenta: dejarlo acá lo vuelve una promesa de este widget
      // en vez de algo que depende de cómo esté configurado el tema.
      constraints: const BoxConstraints(
        minWidth: zonaDeToqueMinima,
        minHeight: zonaDeToqueMinima,
      ),
    );
  }
}
