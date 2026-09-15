import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// Animación de 3 barritas tipo ecualizador para marcar la canción que
/// está sonando ahora. Extraído de `pantalla_principal.dart` (donde
/// vivía como clase privada `_IndicadorSonando`) porque es completamente
/// autocontenido: no depende de nada del estado de esa pantalla.
class IndicadorSonando extends StatefulWidget {
  const IndicadorSonando({super.key});

  @override
  State<IndicadorSonando> createState() => _IndicadorSonandoState();
}

class _IndicadorSonandoState extends State<IndicadorSonando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 16,
          height: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final fase = i * 0.33;
              final t = (_controller.value + fase) % 1.0;
              final alto = 3.0 + 8.0 * (1 - (2 * t - 1).abs());
              return Container(
                width: 2.5,
                height: alto,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
