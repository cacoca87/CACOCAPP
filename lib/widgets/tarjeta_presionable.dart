import 'package:flutter/material.dart';

/// Envuelve a [child] con una animación de "presionado" (se achica un
/// poco al tocar). Extraído de `pantalla_principal.dart` (donde vivía
/// como clase privada `_TarjetaPresionable`) porque es completamente
/// autocontenido: no depende de nada del estado de esa pantalla.
class TarjetaPresionable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const TarjetaPresionable({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<TarjetaPresionable> createState() => _TarjetaPresionableState();
}

class _TarjetaPresionableState extends State<TarjetaPresionable> {
  bool _presionada = false;

  void _setPresionada(bool valor) {
    if (_presionada != valor) setState(() => _presionada = valor);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPresionada(true),
      onTapUp: (_) => _setPresionada(false),
      onTapCancel: () => _setPresionada(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionada ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
