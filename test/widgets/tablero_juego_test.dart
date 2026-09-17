import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/widgets/tablero_juego.dart';

/// El tablero que comparten los cuatro juegos.
///
/// Se pinta con `CustomPaint` y no con widgets porque son hasta 240
/// casillas que se redibujan varias veces por segundo. Lo delicado es
/// [CustomPainter.shouldRepaint]: decide si hay que volver a pintar, y
/// equivocarse ahí es o pintar de más (gasta batería) o pintar de menos
/// (el juego se congela).
Widget _conTablero(List<List<int>> celdas) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 500,
          child: TableroJuego(celdas: celdas),
        ),
      ),
    );

/// El dibujante que quedó montado.
CustomPainter _pintorDe(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!;

void main() {
  group('TableroJuego', () {
    testWidgets('un tablero vacío no rompe nada', (tester) async {
      await tester.pumpWidget(_conTablero(const []));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('una matriz normal se dibuja', (tester) async {
      await tester.pumpWidget(_conTablero([
        [0, 1, 0],
        [2, 0, 3],
      ]));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('el tablero conserva su proporción', (tester) async {
      // 3 columnas x 2 filas dentro de una caja de 300x500: el lado de
      // cada casilla lo manda el ancho (100), así que el tablero ocupa
      // 300x200 y se centra, en vez de estirarse.
      await tester.pumpWidget(_conTablero([
        [0, 0, 0],
        [0, 0, 0],
      ]));
      await tester.pump();

      final caja = tester.getSize(find.byType(CustomPaint).last);
      expect(caja.width / caja.height, closeTo(3 / 2, 0.01));
    });

    group('cuándo decide volver a pintar', () {
      testWidgets('SÍ cuando cambió alguna casilla', (tester) async {
        await tester.pumpWidget(_conTablero([
          [0, 0],
          [0, 0],
        ]));
        await tester.pump();
        final antes = _pintorDe(tester);

        await tester.pumpWidget(_conTablero([
          [0, 1],
          [0, 0],
        ]));
        await tester.pump();

        expect(_pintorDe(tester).shouldRepaint(antes), isTrue);
      });

      testWidgets('NO cuando el tablero quedó igual', (tester) async {
        // Es lo que hace que no se repinte cuando lo único que cambió
        // fue el puntaje de arriba. No alcanzaba con comparar las
        // listas por identidad: el juego devuelve una lista NUEVA en
        // cada cuadro, así que nunca coincidían y siempre repintaba.
        await tester.pumpWidget(_conTablero([
          [0, 1],
          [2, 0],
        ]));
        await tester.pump();
        final antes = _pintorDe(tester);

        await tester.pumpWidget(_conTablero([
          [0, 1],
          [2, 0],
        ]));
        await tester.pump();

        expect(_pintorDe(tester).shouldRepaint(antes), isFalse,
            reason: 'un tablero idéntico no tiene que volver a pintarse');
      });

      testWidgets('SÍ cuando cambió el tamaño del tablero', (tester) async {
        await tester.pumpWidget(_conTablero([
          [0, 0],
        ]));
        await tester.pump();
        final antes = _pintorDe(tester);

        await tester.pumpWidget(_conTablero([
          [0, 0],
          [0, 0],
        ]));
        await tester.pump();

        expect(_pintorDe(tester).shouldRepaint(antes), isTrue);
      });
    });

    testWidgets('un color fuera de la lista no revienta', (tester) async {
      // Los índices de color se toman con módulo justamente para que un
      // valor inesperado no tire la app abajo en medio de una partida.
      await tester.pumpWidget(_conTablero([
        [99, 1000],
      ]));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
