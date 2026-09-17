import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/widgets/controles_reproduccion.dart';

/// Los cinco botones del reproductor grande.
///
/// Lo que se comprueba acá es de lo más concreto: que se puedan tocar.
/// Los de los costados --aleatorio y repetir-- se dibujaban con un
/// ícono de 26 píxeles y sin nada alrededor, así que la zona que
/// respondía al toque medía exactamente eso. El mínimo recomendado es
/// 48, que es más o menos lo que ocupa la yema del dedo.

void _pantallaDeCelular(WidgetTester tester, {double ancho = 320}) {
  tester.view.physicalSize = Size(ancho, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _controles({
  bool aleatorio = false,
  bool sonando = false,
  int repeticion = 0,
  void Function(String cual)? onTocar,
}) {
  void aviso(String cual) => onTocar?.call(cual);
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: ControlesDeReproduccion(
          aleatorioActivo: aleatorio,
          onAleatorio: () => aviso('aleatorio'),
          onAnterior: () => aviso('anterior'),
          onSiguiente: () => aviso('siguiente'),
          sonando: sonando,
          onPlayPausa: () => aviso('playpausa'),
          modoDeRepeticion: repeticion,
          onRepetir: () => aviso('repetir'),
          colorDelResplandor: const Color(0xFFD9962E),
        ),
      ),
    ),
  );
}

void main() {
  group('ControlesDeReproduccion', () {
    testWidgets('TODOS los botones se pueden tocar con el dedo',
        (tester) async {
      // 48x48 es el mínimo recomendado. Antes los de las puntas medían
      // 26, y encima son los que quedan más lejos del pulgar.
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_controles());
      await tester.pump();

      final botones = find.byType(IconButton);
      expect(botones, findsNWidgets(5));

      for (var i = 0; i < 5; i++) {
        final tamano = tester.getSize(botones.at(i));
        expect(tamano.width,
            greaterThanOrEqualTo(ControlesDeReproduccion.zonaDeToqueMinima),
            reason: 'el botón $i mide ${tamano.width} de ancho');
        expect(tamano.height,
            greaterThanOrEqualTo(ControlesDeReproduccion.zonaDeToqueMinima),
            reason: 'el botón $i mide ${tamano.height} de alto');
      }
    });

    for (final ancho in [320.0, 360.0, 412.0]) {
      testWidgets('los cinco entran en una pantalla de ${ancho.toInt()}',
          (tester) async {
        // Agrandar la zona de toque hace que la fila ocupe más: hay que
        // comprobar que sigue entrando en el celular más angosto que se
        // usa hoy.
        _pantallaDeCelular(tester, ancho: ancho);
        await tester.pumpWidget(_controles());
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con $ancho de ancho la fila se desbordó');
      });
    }

    testWidgets('cada botón avisa lo suyo', (tester) async {
      final tocados = <String>[];
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_controles(onTocar: tocados.add));
      await tester.pump();

      for (final ayuda in [
        'Aleatorio (desactivado)',
        'Anterior',
        'Reproducir',
        'Siguiente',
        'Repetir (desactivado)',
      ]) {
        await tester.tap(find.byTooltip(ayuda));
        await tester.pump();
      }

      expect(tocados,
          ['aleatorio', 'anterior', 'playpausa', 'siguiente', 'repetir']);
    });

    testWidgets('el botón grande cambia entre play y pausa', (tester) async {
      _pantallaDeCelular(tester);

      await tester.pumpWidget(_controles(sonando: false));
      await tester.pump();
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      await tester.pumpWidget(_controles(sonando: true));
      await tester.pump();
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    });

    group('el botón de repetir dice en qué modo está', () {
      // Los tres modos tienen que verse distinto: si no, no hay forma
      // de saber en cuál estás sin probar.
      const esperado = {
        0: 'Repetir (desactivado)',
        1: 'Repetir todo (activado)',
        2: 'Repetir una canción (activado)',
      };

      esperado.forEach((modo, ayuda) {
        testWidgets('modo $modo', (tester) async {
          _pantallaDeCelular(tester);
          await tester.pumpWidget(_controles(repeticion: modo));
          await tester.pump();

          expect(find.byTooltip(ayuda), findsOneWidget);
        });
      });

      testWidgets('repetir una sola canción tiene su propio ícono',
          (tester) async {
        _pantallaDeCelular(tester);
        await tester.pumpWidget(_controles(repeticion: 2));
        await tester.pump();
        expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);

        await tester.pumpWidget(_controles(repeticion: 1));
        await tester.pump();
        expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      });
    });

    testWidgets('aleatorio y repetir se ven encendidos cuando lo están',
        (tester) async {
      _pantallaDeCelular(tester);
      await tester.pumpWidget(_controles(aleatorio: true, repeticion: 1));
      await tester.pump();

      final apagados = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) =>
              i.icon == Icons.shuffle_rounded || i.icon == Icons.repeat_rounded)
          .where((i) => i.color == const Color(0xFF9C9186));
      expect(apagados, isEmpty,
          reason: 'estando encendidos no pueden verse en gris');
    });
  });
}
