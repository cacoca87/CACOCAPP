import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CACOCAPP/services/lyrics_service.dart';
import 'package:CACOCAPP/widgets/letra_sincronizada.dart';

/// La letra que se resalta al ritmo de la música.
///
/// Se reescribió su corazón hace poco: antes iba envuelta en un
/// `StreamBuilder` que rehacía la lista entera cinco veces por segundo,
/// y ahora escucha la posición por su cuenta y solo redibuja cuando
/// cambia el renglón. Estos tests comprueban que ese cambio no rompió
/// lo que tenía que seguir haciendo.

final _lineas = [
  const LineaLetra(Duration(seconds: 0), 'primera'),
  const LineaLetra(Duration(seconds: 10), 'segunda'),
  const LineaLetra(Duration(seconds: 20), 'tercera'),
];

/// El tamaño de letra con el que se dibujó un renglón. El que suena va
/// más grande que el resto: así se sabe cuál está resaltado.
/// Se lee del texto YA DIBUJADO, no del widget de estilo: es lo que la
/// persona ve de verdad, y evita depender de cómo esté envuelto.
double _tamanoDe(WidgetTester tester, String texto) {
  final parrafo = tester.renderObject<RenderParagraph>(find.text(texto));
  return parrafo.text.style!.fontSize!;
}

Future<StreamController<Duration>> _montar(
  WidgetTester tester, {
  ValueChanged<Duration>? onTocarLinea,
}) async {
  final posicion = StreamController<Duration>.broadcast();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: LetraSincronizada(
        lineas: _lineas,
        posicion: posicion.stream,
        onTocarLinea: onTocarLinea,
        claveDeAjuste: 'cancion-de-prueba',
      ),
    ),
  ));
  await tester.pump();
  return posicion;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LetraSincronizada', () {
    testWidgets('resalta el renglón que corresponde a la posición',
        (tester) async {
      final posicion = await _montar(tester);
      addTearDown(posicion.close);

      posicion.add(const Duration(seconds: 12));
      await tester.pumpAndSettle();

      expect(_tamanoDe(tester, 'segunda'),
          greaterThan(_tamanoDe(tester, 'primera')),
          reason: 'a los 12 segundos tiene que estar sonando la segunda');
    });

    testWidgets('va cambiando de renglón mientras avanza la canción',
        (tester) async {
      final posicion = await _montar(tester);
      addTearDown(posicion.close);

      posicion.add(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_tamanoDe(tester, 'primera'),
          greaterThan(_tamanoDe(tester, 'segunda')));

      posicion.add(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      expect(_tamanoDe(tester, 'tercera'),
          greaterThan(_tamanoDe(tester, 'segunda')));
    });

    testWidgets('antes de que empiece, no hay ningún renglón resaltado',
        (tester) async {
      final posicion = await _montar(tester);
      addTearDown(posicion.close);

      // Todos del mismo tamaño: ninguno está sonando todavía.
      final primera = _tamanoDe(tester, 'primera');
      expect(_tamanoDe(tester, 'segunda'), primera);
      expect(_tamanoDe(tester, 'tercera'), primera);
    });

    testWidgets('tocar un renglón pide saltar a su momento', (tester) async {
      Duration? pedido;
      final posicion = await _montar(tester, onTocarLinea: (d) => pedido = d);
      addTearDown(posicion.close);

      await tester.tap(find.text('tercera'));
      await tester.pump();

      expect(pedido, const Duration(seconds: 20));
    });

    testWidgets('sin acción de salto, tocar un renglón no rompe nada',
        (tester) async {
      // El panel del video la usa así cuando saltar no es confiable.
      final posicion = await _montar(tester);
      addTearDown(posicion.close);

      await tester.tap(find.text('tercera'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('los botones de desfase cambian el renglón EN EL ACTO',
        (tester) async {
      // No se espera al próximo aviso de la reproducción, que puede
      // tardar hasta un quinto de segundo y hace sentir el botón lento.
      final posicion = await _montar(tester);
      addTearDown(posicion.close);

      // A los 11 segundos suena la segunda.
      posicion.add(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(_tamanoDe(tester, 'segunda'),
          greaterThan(_tamanoDe(tester, 'primera')));

      // Se retrasa la letra 2 segundos (cuatro toques de medio segundo):
      // 11 - 2 = 9, que todavía es la PRIMERA.
      for (var i = 0; i < 4; i++) {
        await tester.tap(
            find.byTooltip('La letra va adelantada: retrasarla medio segundo'));
        await tester.pump();
      }
      // El resaltado se anima en 200 ms: hay que dejar que termine
      // antes de medir lo que quedó dibujado. Lo que se comprueba es
      // que el cambio arranque con el toque y NO con el próximo aviso
      // de la reproducción, que acá nunca llega: el flujo no emite
      // nada más después de los 11 segundos.
      await tester.pumpAndSettle();

      expect(_tamanoDe(tester, 'primera'),
          greaterThan(_tamanoDe(tester, 'segunda')),
          reason: 'el renglón tiene que cambiar sin esperar otro aviso');
    });

    testWidgets('al cambiar de canción se deja de escuchar la anterior',
        (tester) async {
      // Si la suscripción vieja quedara viva, la letra de la canción
      // nueva se movería al ritmo de la anterior.
      final vieja = StreamController<Duration>.broadcast();
      final nueva = StreamController<Duration>.broadcast();
      addTearDown(vieja.close);
      addTearDown(nueva.close);

      Widget conPosicion(Stream<Duration> p, String clave) => MaterialApp(
            home: Scaffold(
              body: LetraSincronizada(
                lineas: _lineas,
                posicion: p,
                claveDeAjuste: clave,
              ),
            ),
          );

      await tester.pumpWidget(conPosicion(vieja.stream, 'una'));
      await tester.pump();
      await tester.pumpWidget(conPosicion(nueva.stream, 'otra'));
      await tester.pump();

      // La vieja ya no tiene que mover nada.
      vieja.add(const Duration(seconds: 25));
      await tester.pump();
      final primera = _tamanoDe(tester, 'primera');
      expect(_tamanoDe(tester, 'tercera'), primera,
          reason: 'la canción anterior no puede seguir moviendo la letra');

      // La nueva sí.
      nueva.add(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      expect(_tamanoDe(tester, 'tercera'), greaterThan(primera));
    });
  });
}
