import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// Una tarjeta con fondo propio que se puede tocar, y que **sí muestra
/// el destello** al tocarla.
///
/// POR QUÉ HACE FALTA UN WIDGET PARA ESTO
///
/// El destello circular que se expande bajo el dedo no lo dibuja el
/// `InkWell`: lo dibuja la capa `Material` más cercana **por debajo**.
/// Así que si entre el `InkWell` y esa capa hay algo con fondo opaco
/// --una tarjeta con su color, por ejemplo-- el destello queda tapado.
/// La tarjeta responde igual al toque, pero se siente muerta: no pasa
/// nada visible entre que se apoya el dedo y que la pantalla cambia.
///
/// Es un fallo que no se ve leyendo el código y que tampoco tira ningún
/// error: simplemente falta algo. Aparecía en seis lugares, todos de
/// los más tocados de la app --el acceso a "Toda tu música", el
/// buscador de videos, los accesos rápidos, las tarjetas de los juegos,
/// cada noticia y cada tarjeta de Artistas y Álbumes--.
///
/// La solución es dar vuelta el orden: **primero** la capa `Material`
/// con el color de la tarjeta, y el `InkWell` adentro. Así el destello
/// se dibuja encima del fondo y no debajo.
class TarjetaTocable extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final Color color;

  /// Borde y sombra van en una caja de AFUERA, sin color propio: si
  /// llevaran color volverían a tapar el destello, que es justo el
  /// problema que este widget existe para evitar.
  final BoxBorder? borde;
  final List<BoxShadow>? sombra;

  const TarjetaTocable({
    super.key,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = 12,
    this.color = AppTheme.surface,
    this.borde,
    this.sombra,
  });

  @override
  Widget build(BuildContext context) {
    final bordeRedondeado = BorderRadius.circular(radio);

    Widget tarjeta = Material(
      color: color,
      borderRadius: bordeRedondeado,
      // Recorta el destello a las esquinas redondeadas: sin esto se
      // desborda por las cuatro puntas y se ve un cuadrado.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (borde != null || sombra != null) {
      tarjeta = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: bordeRedondeado,
          border: borde,
          boxShadow: sombra,
        ),
        child: tarjeta,
      );
    }

    return tarjeta;
  }
}
