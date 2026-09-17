import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/widgets/indicador_sonando.dart';
import 'package:CACOCAPP/widgets/tarjeta_presionable.dart';

/// Las dos piezas más chicas de la app, que no tenían ningún test.
///
/// Son chicas pero no son inocentes: una anima sin parar (o sea que
/// deja un reloj corriendo) y la otra guarda estado del toque. Las dos
/// cosas se rompen callado: la animación queda viva después de salir de
/// la pantalla, o la tarjeta se queda achicada para siempre.

void main() {
  group('TarjetaPresionable', () {
    testWidgets('el toque llega', (tester) async {
      var toques = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TarjetaPresionable(
            onTap: () => toques++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ));

      await tester.tap(find.byType(TarjetaPresionable));
      await tester.pump();

      expect(toques, 1);
    });

    testWidgets('se achica al apoyar el dedo y vuelve al soltarlo',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: TarjetaPresionable(
              onTap: () {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ));

      double escalaActual() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      expect(escalaActual(), 1.0);

      final gesto = await tester.startGesture(
          tester.getCenter(find.byType(TarjetaPresionable)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(escalaActual(), lessThan(1.0),
          reason: 'con el dedo apoyado tiene que verse achicada');

      await gesto.up();
      await tester.pumpAndSettle();
      expect(escalaActual(), 1.0, reason: 'al soltar tiene que volver');
    });

    testWidgets('si el toque se cancela, no se queda achicada',
        (tester) async {
      // Pasa al arrastrar el dedo fuera de la tarjeta: sin esto, la
      // tarjeta se quedaba chiquita para siempre.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: TarjetaPresionable(
              onTap: () {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ));

      final gesto = await tester.startGesture(
          tester.getCenter(find.byType(TarjetaPresionable)));
      await tester.pump(const Duration(milliseconds: 150));
      await gesto.cancel();
      await tester.pumpAndSettle();

      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1.0);
    });
  });

  group('IndicadorSonando', () {
    testWidgets('se dibuja y no revienta', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: IndicadorSonando())),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(IndicadorSonando), findsOneWidget);
    });

    testWidgets('las barritas se mueven', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: IndicadorSonando())),
      ));
      await tester.pump();

      List<double> altos() => tester
          .widgetList<Container>(find.descendant(
            of: find.byType(IndicadorSonando),
            matching: find.byType(Container),
          ))
          .map((c) => c.constraints?.maxHeight ?? 0)
          .toList();

      final antes = altos();
      await tester.pump(const Duration(milliseconds: 300));
      expect(altos(), isNot(antes), reason: 'la animación no se movió');
    });

    testWidgets('al salir de la pantalla no queda la animación corriendo',
        (tester) async {
      // Una animación que se repite para siempre sin soltarse es un
      // reloj latiendo por nada: si no se libera al salir, sigue
      // gastando batería con la pantalla mostrando otra cosa.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: IndicadorSonando())),
      ));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull,
          reason: 'quedó una animación viva después de salir');
    });
  });
}
