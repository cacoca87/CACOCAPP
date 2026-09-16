import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/app_theme.dart';

/// Botón redondo de los controles de los juegos. Es grande a propósito:
/// se juega con el pulgar y en movimiento, así que un botón chico se
/// falla todo el tiempo.
class BotonJuego extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  final String tooltip;
  final double tamano;

  const BotonJuego({
    super.key,
    required this.icono,
    required this.onTap,
    required this.tooltip,
    this.tamano = 62,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.surfaceRaised,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: tamano,
            height: tamano,
            child: Icon(icono, color: AppTheme.amber, size: tamano * 0.42),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Dato(etiqueta: 'PUNTAJE', valor: '$puntaje', destacado: true),
        _Dato(etiqueta: 'NIVEL', valor: '$nivel'),
        if (etiquetaExtra.isNotEmpty)
          _Dato(etiqueta: etiquetaExtra, valor: '$valorExtra'),
        _Dato(etiqueta: 'RÉCORD', valor: '$record'),
      ],
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
          Text('$puntaje puntos', style: AppTheme.body),
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
