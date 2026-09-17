import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/app_theme.dart';
import '../utils/plural.dart';

/// Botón redondo de los controles de los juegos. Es grande a propósito:
/// se juega con el pulgar y en movimiento, así que un botón chico se
/// falla todo el tiempo.
///
/// Mantenerlo apretado repite la acción, cada vez más rápido. Sin eso
/// había que dar un toque por cada casillero, que para mover una pieza
/// de un lado al otro son ocho o nueve toques y se siente brusco.
class BotonJuego extends StatefulWidget {
  final IconData icono;
  final VoidCallback onTap;
  final String tooltip;
  final double tamano;

  /// Si es `false`, la acción se dispara una sola vez por toque. Sirve
  /// para cosas que no tiene sentido repetir, como tirar la pieza al
  /// fondo de una vez.
  final bool repetible;

  const BotonJuego({
    super.key,
    required this.icono,
    required this.onTap,
    required this.tooltip,
    this.tamano = 62,
    this.repetible = true,
  });

  @override
  State<BotonJuego> createState() => _BotonJuegoState();
}

class _BotonJuegoState extends State<BotonJuego> {
  Timer? _repeticion;
  int _vecesRepetido = 0;

  /// Cuánto se espera antes de empezar a repetir. Sin esta pausa, un
  /// toque normal dispararía dos acciones.
  static const _esperaInicial = Duration(milliseconds: 300);

  @override
  void dispose() {
    _repeticion?.cancel();
    super.dispose();
  }

  void _presionar() {
    // Por las dudas quedara uno andando de un toque anterior: dos
    // temporizadores repitiendo a la vez movían la pieza al doble de
    // velocidad y solo se podía frenar uno.
    _repeticion?.cancel();
    HapticFeedback.selectionClick();
    widget.onTap();
    if (!widget.repetible) return;
    _vecesRepetido = 0;
    _repeticion = Timer(_esperaInicial, _repetir);
  }

  void _repetir() {
    widget.onTap();
    _vecesRepetido++;
    // Acelera con cada repetición, hasta un tope: mantener apretado
    // tiene que sentirse como que la pieza se desliza, no como toques
    // sueltos muy seguidos.
    final ms = (150 - _vecesRepetido * 12).clamp(55, 150);
    _repeticion = Timer(Duration(milliseconds: ms), _repetir);
  }

  void _soltar() {
    _repeticion?.cancel();
    _repeticion = null;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      // MANUAL, o sea: el texto de ayuda queda para el lector de
      // pantalla pero NO se muestra al mantener apretado.
      //
      // Por defecto un `Tooltip` aparece con una pulsación larga, y para
      // eso compite por el gesto con el botón. A los 500 ms gana el
      // tooltip, el toque se CANCELA y la repetición se corta --justo
      // cuando el botón tendría que estar acelerando--.
      //
      // O sea que mantener apretado para mover la pieza funcionaba
      // medio segundo y después se plantaba, con un cartelito encima.
      // En los cuatro juegos.
      triggerMode: TooltipTriggerMode.manual,
      child: Material(
        color: AppTheme.surfaceRaised,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          // La acción se dispara en `onTapDown` y no en `onTap` para que
          // la repetición pueda arrancar apenas se apoya el dedo.
          onTapDown: (_) => _presionar(),
          onTapUp: (_) => _soltar(),
          onTapCancel: _soltar,
          onTap: () {},
          child: SizedBox(
            width: widget.tamano,
            height: widget.tamano,
            child: Icon(widget.icono,
                color: AppTheme.amber, size: widget.tamano * 0.42),
          ),
        ),
      ),
    );
  }
}

/// Marcador de arriba de los juegos: puntaje, nivel y récord.
class MarcadorJuego extends StatelessWidget {
  final int puntaje;
  final int nivel;
  final int record;
  final String etiquetaExtra;
  final int valorExtra;

  const MarcadorJuego({
    super.key,
    required this.puntaje,
    required this.nivel,
    required this.record,
    this.etiquetaExtra = '',
    this.valorExtra = 0,
  });

  @override
  Widget build(BuildContext context) {
    // FittedBox para que, con la letra del sistema agrandada, las
    // cuatro columnas se achiquen en vez de desbordarse fuera de la
    // pantalla.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Dato(etiqueta: 'PUNTAJE', valor: '$puntaje', destacado: true),
          _Dato(etiqueta: 'NIVEL', valor: '$nivel'),
          if (etiquetaExtra.isNotEmpty)
            _Dato(etiqueta: etiquetaExtra, valor: '$valorExtra'),
          _Dato(etiqueta: 'RÉCORD', valor: '$record'),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool destacado;

  const _Dato({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: AppTheme.small.copyWith(fontSize: 10, letterSpacing: 1.1),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: AppTheme.heading.copyWith(
            fontSize: destacado ? 22 : 17,
            color: destacado ? AppTheme.amber : AppTheme.paper,
          ),
        ),
      ],
    );
  }
}

/// Cartel de "perdiste" con el puntaje final y el botón de volver a
/// jugar. Se muestra encima del tablero.
class CartelFinDeJuego extends StatelessWidget {
  final int puntaje;
  final bool esRecord;
  final VoidCallback onReiniciar;

  const CartelFinDeJuego({
    super.key,
    required this.puntaje,
    required this.esRecord,
    required this.onReiniciar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.ink.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            esRecord ? '¡Nuevo récord!' : 'Fin del juego',
            style: AppTheme.heading.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(contar(puntaje, 'punto', 'puntos'), style: AppTheme.body),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: AppTheme.primaryButton,
            onPressed: onReiniciar,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Jugar de nuevo'),
          ),
        ],
      ),
    );
  }
}
