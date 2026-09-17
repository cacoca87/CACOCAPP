import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/services/jamendo_service.dart';
import 'package:CACOCAPP/widgets/fila_de_generos.dart';

/// La fila de géneros de Descubrir.
///
/// Tenía el alto escrito a mano. Se midió esperando un desbordado con
/// la letra grande --el mismo fallo de los carruseles de Inicio-- y NO
/// lo había: el número solo achataba los chips con la letra normal. Los
/// tests de desborde quedan igual, para que nadie lo tenga que volver a
/// medir.
///
/// La pantalla entera no se puede probar --necesita el motor de audio
/// del celular-- así que la fila vive aparte.

void _pantallaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _fila({
  String? activo,
  double letra = 1.0,
  void Function(String, String)? onElegir,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(letra)),
      child: Scaffold(
        body: Column(
          children: [
            FilaDeGeneros(
              generoActivo: activo,
              onElegirGenero: onElegir ?? (_, __) {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('FilaDeGeneros', () {
    // 1.0 es la letra normal; 2.0 es el máximo que deja poner Android
    // en accesibilidad.
    for (final escala in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('no se desborda con la letra x$escala', (tester) async {
        _pantallaDeCelular(tester);
        await tester.pumpWidget(_fila(letra: escala));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con la letra x$escala se desbordó la fila de géneros');
      });
    }

    testWidgets('están los doce géneros', (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_fila());
      await tester.pump();

      expect(find.byType(ChoiceChip),
          findsNWidgets(JamendoService.generos.length));
    });

    testWidgets('tocar un género avisa con su nombre y su etiqueta',
        (tester) async {
      // La etiqueta es lo que entiende Jamendo ("rock"), y el nombre lo
      // que se lee en pantalla ("Rock"). Si se mandara el nombre, la
      // búsqueda de "Electrónica" o "Clásica" no encontraría nada.
      String? nombre;
      String? etiqueta;
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_fila(onElegir: (n, e) {
        nombre = n;
        etiqueta = e;
      }));
      await tester.pump();

      await tester.tap(find.text('Rock'));
      await tester.pump();

      expect(nombre, 'Rock');
      expect(etiqueta, 'rock');
    });

    testWidgets('el género elegido se ve marcado y los demás no',
        (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_fila(activo: 'Jazz'));
      await tester.pump();

      final marcados = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((c) => c.selected)
          .toList();
      expect(marcados.length, 1);
    });

    testWidgets('sin ninguno elegido, ninguno se ve marcado', (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_fila(activo: null));
      await tester.pump();

      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .any((c) => c.selected),
        isFalse,
      );
    });

    testWidgets('todos los géneros tienen su etiqueta de Jamendo',
        (tester) async {
      // Un género sin etiqueta abriría una búsqueda vacía.
      for (final entry in JamendoService.generos.entries) {
        expect(entry.value.trim(), isNotEmpty,
            reason: '"${entry.key}" no tiene etiqueta');
      }
    });

    testWidgets('se puede desplazar de punta a punta', (tester) async {
      // Doce géneros no entran en un celular: si no se pudiera arrastrar
      // la fila, los últimos serían inalcanzables.
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_fila());
      await tester.pump();

      await tester.drag(find.byType(ChoiceChip).first, const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Mundo'), findsOneWidget);
    });
  });
}
