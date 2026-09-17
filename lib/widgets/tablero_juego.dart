import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

/// Dibuja la cuadrícula de los cuatro juegos.
///
/// Se pinta con `CustomPaint` y no con widgets: un tablero de Tetris son
/// 200 celdas, y rehacer 200 widgets en cada paso del juego (varias
/// veces por segundo) da tirones. Pintar es una sola pasada.
///
/// [celdas] es una matriz donde 0 es vacío y cualquier otro número
/// identifica el color.
class TableroJuego extends StatelessWidget {
  final List<List<int>> celdas;

  const TableroJuego({super.key, required this.celdas});

  /// Los colores de las piezas, en la paleta de la app. El índice 0 no
  /// se usa (es la celda vacía).
  static const List<Color> colores = [
    Colors.transparent,
    AppTheme.amber,
    Color(0xFFE8B65E),
    AppTheme.ember,
    Color(0xFF7FA05A),
    Color(0xFFC96A3B),
    Color(0xFF5E8AA8),
    Color(0xFFB08BC4),
  ];

  @override
  Widget build(BuildContext context) {
    final filas = celdas.length;
    final columnas = filas == 0 ? 0 : celdas[0].length;
    if (filas == 0 || columnas == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // El tablero conserva su proporción y se centra, para que no se
        // deforme en pantallas de distinto alto.
        final ladoCelda = (constraints.maxWidth / columnas)
            .clamp(0.0, constraints.maxHeight / filas);
        return Center(
          child: SizedBox(
            width: ladoCelda * columnas,
            height: ladoCelda * filas,
            child: CustomPaint(
              painter: _PintorTablero(celdas),
              size: Size(ladoCelda * columnas, ladoCelda * filas),
            ),
          ),
        );
      },
    );
  }
}

class _PintorTablero extends CustomPainter {
  final List<List<int>> celdas;
  _PintorTablero(this.celdas);

  @override
  void paint(Canvas canvas, Size size) {
    final filas = celdas.length;
    final columnas = celdas[0].length;
    final lado = size.width / columnas;

    final fondo = Paint()..color = AppTheme.ink;
    canvas.drawRect(Offset.zero & size, fondo);

    final vacia = Paint()
      ..color = AppTheme.hairline.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Estos dos se crean UNA vez y se les cambia el color adentro del
    // bucle. Antes se creaba un `Paint` nuevo por cada casillero
    // pintado: en un tablero de 12x20 son hasta 480 objetos nuevos por
    // cuadro, y los juegos redibujan varias veces por segundo.
    final relleno = Paint();
    final borde = Paint()..color = AppTheme.ink.withValues(alpha: 0.55);

    for (var y = 0; y < filas; y++) {
      for (var x = 0; x < columnas; x++) {
        final rect =
            Rect.fromLTWH(x * lado, y * lado, lado, lado).deflate(lado * 0.06);
        final rrect =
            RRect.fromRectAndRadius(rect, Radius.circular(lado * 0.15));
        final valor = celdas[y][x];
        if (valor == 0) {
          canvas.drawRRect(rrect, vacia);
        } else {
          relleno.color =
              TableroJuego.colores[valor % TableroJuego.colores.length];
          canvas.drawRRect(rrect, relleno);
          // Un borde más oscuro le da el aspecto de ficha del juego
          // original, en vez de un cuadrado plano.
          canvas.drawRRect(rrect.deflate(lado * 0.18), borde);
        }
      }
    }
  }

  /// Se compara casillero por casillero en vez de devolver siempre
  /// `true`.
  ///
  /// La vista del juego es una lista NUEVA en cada cuadro, así que
  /// compararla por identidad no sirve de nada. Recorrer doscientos
  /// números enteros es muchísimo más barato que volver a dibujar el
  /// tablero entero, y hay redibujados que no lo necesitan: cuando
  /// cambia solo el puntaje de arriba, por ejemplo, el tablero es
  /// idéntico.
  @override
  bool shouldRepaint(_PintorTablero anterior) {
    final otras = anterior.celdas;
    if (otras.length != celdas.length) return true;
    for (var y = 0; y < celdas.length; y++) {
      final fila = celdas[y];
      final otraFila = otras[y];
      if (fila.length != otraFila.length) return true;
      for (var x = 0; x < fila.length; x++) {
        if (fila[x] != otraFila[x]) return true;
      }
    }
    return false;
  }
}
