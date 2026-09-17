import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/widgets/controles_juego.dart';

/// Los controles que comparten los cuatro juegos.
///
/// Lo delicado acá es el botón que se puede mantener apretado: repite
/// la acción cada vez más rápido, y equivocarse en eso es o que la
/// pieza no se mueva, o que se dispare sola, o que siga moviéndose
/// después de soltar el dedo.

void _pantallaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _conBoton({
  required VoidCallback onTap,
  bool repetible = true,
  double letra = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(letra)),
      child: Scaffold(
        body: Center(
          child: BotonJuego(
            icono: Icons.arrow_left_rounded,
            onTap: onTap,
            tooltip: 'Izquierda',
            repetible: repetible,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('BotonJuego', () {
    testWidgets('un toque suelto dispara la acción UNA vez', (tester) async {
      var veces = 0;
      await tester.pumpWidget(_conBoton(onTap: () => veces++));

      await tester.tap(find.byType(BotonJuego));
      await tester.pump();

      expect(veces, 1);
      // Y no sigue disparando después de soltar.
      await tester.pump(const Duration(seconds: 1));
      expect(veces, 1, reason: 'siguió repitiendo con el dedo levantado');
    });

    testWidgets('la acción sale al APOYAR el dedo, no al soltarlo',
        (tester) async {
      // En un juego, esperar a que levantes el dedo se siente lento.
      var veces = 0;
      await tester.pumpWidget(_conBoton(onTap: () => veces++));

      final gesto = await tester.startGesture(
          tester.getCenter(find.byType(BotonJuego)));
      // Flutter no declara "apoyó el dedo" en el mismo instante: espera
      // un momento para descartar que sea el arranque de un arrastre.
      // Por eso acá hay que dejar pasar ese momento.
      await tester.pump(const Duration(milliseconds: 150));
      expect(veces, 1, reason: 'tenía que dispararse al apoyar');

      // Y sin haber levantado el dedo todavía.
      await gesto.up();
      await tester.pump();
    });

    testWidgets('manteniéndolo apretado repite, y cada vez más rápido',
        (tester) async {
      var veces = 0;
      await tester.pumpWidget(_conBoton(onTap: () => veces++));

      final gesto = await tester.startGesture(
          tester.getCenter(find.byType(BotonJuego)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(veces, 1);

      // Desde que se apoya el dedo hay 300 ms de pausa antes de empezar
      // a repetir: sin ella, un toque normal dispararía dos acciones.
      await tester.pump(const Duration(milliseconds: 200)); // 250 ms
      expect(veces, 1, reason: 'repitió antes de la pausa inicial');

      await tester.pump(const Duration(milliseconds: 200)); // 450 ms
      expect(veces, greaterThanOrEqualTo(2),
          reason: 'pasada la pausa tenía que repetir');

      // De a pasos chicos y no de un salto: cada repetición programa la
      // siguiente, así que hay que dejar que el reloj las vaya soltando
      // de a una.
      final alSegundoToque = veces;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(veces, greaterThan(alSegundoToque + 5),
          reason: 'manteniendo apretado un segundo tiene que repetir varias '
              'veces');

      await gesto.up();
      await tester.pump();
      final alSoltar = veces;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(veces, alSoltar,
          reason: 'al soltar el dedo tiene que dejar de repetir');
    });

    testWidgets('cancelar el toque también lo frena', (tester) async {
      // Pasa al arrastrar el dedo fuera del botón sin levantarlo.
      var veces = 0;
      await tester.pumpWidget(_conBoton(onTap: () => veces++));

      final gesto = await tester.startGesture(
          tester.getCenter(find.byType(BotonJuego)));
      await tester.pump(const Duration(milliseconds: 400));
      final antes = veces;

      await gesto.cancel();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(veces, antes, reason: 'siguió repitiendo tras cancelar el toque');
    });

    testWidgets('un botón NO repetible se dispara una sola vez aunque lo '
        'mantengas', (tester) async {
      // Es el de tirar la pieza al fondo: repetirlo no tiene sentido.
      var veces = 0;
      await tester
          .pumpWidget(_conBoton(onTap: () => veces++, repetible: false));

      final gesto = await tester.startGesture(
          tester.getCenter(find.byType(BotonJuego)));
      await tester.pump(const Duration(seconds: 2));

      expect(veces, 1);
      await gesto.up();
      await tester.pump();
    });

    testWidgets('salir de la pantalla con el dedo apoyado no deja nada '
        'corriendo', (tester) async {
      var veces = 0;
      await tester.pumpWidget(_conBoton(onTap: () => veces++));

      final gesto = await tester.startGesture(
          tester.getCenter(find.byType(BotonJuego)));
      await tester.pump(const Duration(milliseconds: 400));

      // Se destruye la pantalla mientras el dedo sigue apoyado.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull,
          reason: 'quedó un temporizador vivo después de salir');
      await gesto.up();
    });
  });

  group('MarcadorJuego', () {
    for (final escala in [1.0, 1.6, 2.0]) {
      testWidgets('no se desborda con la letra x$escala', (tester) async {
        // Cuatro columnas de números en el ancho de un celular.
        _pantallaDeCelular(tester);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(escala)),
            child: const Scaffold(
              body: MarcadorJuego(
                puntaje: 999999,
                nivel: 99,
                record: 999999,
                etiquetaExtra: 'LÍNEAS',
                valorExtra: 9999,
              ),
            ),
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con la letra x$escala se desbordó el marcador');
      });
    }

    testWidgets('sin dato extra muestra solo las tres columnas',
        (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MarcadorJuego(puntaje: 10, nivel: 1, record: 50),
        ),
      ));
      await tester.pump();

      expect(find.text('PUNTAJE'), findsOneWidget);
      expect(find.text('NIVEL'), findsOneWidget);
      expect(find.text('RÉCORD'), findsOneWidget);
      expect(find.text('LÍNEAS'), findsNothing);
    });
  });

  group('CartelFinDeJuego', () {
    testWidgets('dice "récord" solo cuando de verdad lo fue', (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CartelFinDeJuego(
            puntaje: 120,
            esRecord: true,
            onReiniciar: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('¡Nuevo récord!'), findsOneWidget);
      expect(find.text('Fin del juego'), findsNothing);
    });

    testWidgets('sin récord dice "Fin del juego"', (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CartelFinDeJuego(
            puntaje: 120,
            esRecord: false,
            onReiniciar: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Fin del juego'), findsOneWidget);
    });

    testWidgets('un solo punto va en singular', (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CartelFinDeJuego(
            puntaje: 1,
            esRecord: false,
            onReiniciar: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('1 punto'), findsOneWidget);
    });

    testWidgets('el botón de volver a jugar avisa', (tester) async {
      var reinicios = 0;
      _pantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CartelFinDeJuego(
            puntaje: 5,
            esRecord: false,
            onReiniciar: () => reinicios++,
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Jugar de nuevo'));
      await tester.pump();

      expect(reinicios, 1);
    });
  });
}
