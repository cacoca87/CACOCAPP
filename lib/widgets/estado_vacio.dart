import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// Mensaje centrado para cuando una pantalla no tiene nada que mostrar.
///
/// Existe para que todos los "no hay nada acá" de la app se vean igual.
/// Antes cada pantalla resolvía el suyo por su cuenta: algunas ponían
/// ícono y texto (con tamaños distintos entre sí) y otras una sola línea
/// de texto gris suelta en el medio de la pantalla, que se lee más como
/// un error que como un estado normal.
///
/// [accion] es opcional, para las pantallas donde hay algo concreto que
/// el usuario puede hacer para salir del estado vacío.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final Widget? accion;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.mensaje,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: AppTheme.mutedInk),
            const SizedBox(height: 14),
            Text(
              mensaje,
              style: AppTheme.body.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (accion != null) ...[
              const SizedBox(height: 18),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}
