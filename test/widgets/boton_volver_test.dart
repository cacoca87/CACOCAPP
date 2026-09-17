import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/widgets/boton_volver.dart';

/// Arma una pantalla con el botón adentro, y otra encima para poder
/// comprobar si de verdad se sale.
Future<void> _abrirPantallaCon(WidgetTester tester, Widget boton) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          child: const Text('entrar'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(leading: boton),
                body: const Text('adentro'),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('entrar'));
  await tester.pumpAndSettle();
  expect(find.text('adentro'), findsOneWidget);
}

void main() {
  group('BotonVolver', () {
    testWidgets('EL BUG QUE ARREGLÓ: sin callback, igual se puede salir',
        (tester) async {
      // Cinco pantallas enchufaban su callback de volver directo al
      // botón. Un `onPressed: null` en Flutter no es "no hace nada":
      // APAGA el botón. Si alguna se abría sin ese callback, quedaba
      // gris y no había forma de salir de la pantalla.
      await _abrirPantallaCon(tester, const BotonVolver(onVolver: null));

      await tester.tap(find.byType(BotonVolver));
      await tester.pumpAndSettle();

      expect(find.text('adentro'), findsNothing,
          reason: 'sin callback tiene que caer en Navigator.pop');
      expect(find.text('entrar'), findsOneWidget);
    });

    testWidgets('el botón NUNCA está apagado', (tester) async {
      await _abrirPantallaCon(tester, const BotonVolver(onVolver: null));

      final boton = tester.widget<IconButton>(find.byType(IconButton));
      expect(boton.onPressed, isNotNull,
          reason: 'un botón de volver apagado deja a la persona encerrada');
    });

    testWidgets('con callback, se usa ese y NO se toca el Navigator',
        (tester) async {
      // Es el caso de las pantallas que no se abren con Navigator sino
      // que se insertan cambiando una variable: ahí `Navigator.pop`
      // vaciaría el Navigator y dejaría la pantalla en negro.
      var llamado = 0;
      await _abrirPantallaCon(tester, BotonVolver(onVolver: () => llamado++));

      await tester.tap(find.byType(BotonVolver));
      await tester.pumpAndSettle();

      expect(llamado, 1);
      expect(find.text('adentro'), findsOneWidget,
          reason: 'no tiene que sacar la ruta: de eso se encarga el callback');
    });

    testWidgets('la versión compacta se comporta igual', (tester) async {
      await _abrirPantallaCon(
          tester, const BotonVolver(onVolver: null, compacto: true));

      await tester.tap(find.byType(BotonVolver));
      await tester.pumpAndSettle();

      expect(find.text('adentro'), findsNothing);
    });
  });
}
