import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/services/audio_effects_service.dart';
import 'package:CACOCAPP/widgets/audio_effects_sheet.dart';

/// El ecualizador, que es la parte de la app que MÁS depende del
/// celular de cada uno.
///
/// Cuántas bandas hay no lo decide la app: lo informa Android según el
/// fabricante. La mayoría dice 5, pero hay equipos que dicen 8 o 10.
/// Con el ancho natural de cada columna, diez no entraban y el panel
/// salía con las rayas amarillas y negras de desbordado.
///
/// Ese arreglo se hizo a ciegas --es imposible verlo en el teléfono
/// donde se programó-- así que estos tests son la única forma de
/// comprobarlo.

List<BandaEcualizador> _bandas(int cuantas) {
  // Frecuencias parecidas a las que informa un Android de verdad. La
  // última es la etiqueta más larga ("12.5kHz"), que es la que primero
  // deja de entrar cuando las columnas se angostan.
  const frecuencias = [
    60,
    230,
    910,
    3600,
    14000,
    100,
    1000,
    12500,
    250,
    8000,
  ];
  return List.generate(
    cuantas,
    (i) => BandaEcualizador(
      indice: i,
      frecuenciaHz: frecuencias[i % frecuencias.length],
      nivel: 0,
    ),
  );
}

/// La fila metida en un ancho fijo, que es lo que de verdad importa
/// acá: el desbordado aparece cuando muchas columnas tienen que entrar
/// en el ancho de un celular. 320 es de los más angostos que todavía se
/// usan; sin este `SizedBox` la prueba correría en una pantalla de 800
/// de ancho, donde diez bandas entran igual y el test no probaría nada.
Widget _panel(int cuantasBandas, {double ancho = 320, double letra = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(letra)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: FilaDeBandas(
              bandas: _bandas(cuantasBandas),
              nivelMinimo: -1500,
              nivelMaximo: 1500,
              habilitado: true,
              nivelDe: (_) => 0,
              onCambiar: (_, __) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FilaDeBandas', () {
    // 5 es lo normal; 8 y 10 son los equipos que rompían el panel.
    for (final cuantas in [1, 3, 5, 8, 10]) {
      testWidgets('$cuantas bandas entran sin desbordarse', (tester) async {
        await tester.pumpWidget(_panel(cuantas));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'con $cuantas bandas el panel se desbordó');
        expect(find.byType(Slider), findsNWidgets(cuantas));
      });
    }

    testWidgets('10 bandas en una pantalla angosta y con la letra al doble',
        (tester) async {
      // El peor caso realista: un celular chico, la letra de
      // accesibilidad al máximo y un ecualizador de diez bandas.
      await tester.pumpWidget(_panel(10, ancho: 320, letra: 2.0));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('todas las columnas miden lo mismo', (tester) async {
      // Es lo que hace que el desbordado sea imposible: reparten el
      // ancho en partes iguales en vez de pedir cada una lo suyo.
      await tester.pumpWidget(_panel(8));
      await tester.pump();

      final anchos = tester
          .widgetList<Slider>(find.byType(Slider))
          .map((s) => tester.getSize(find.byWidget(s)).width)
          .toSet();
      expect(anchos.length, 1, reason: 'todas tienen que medir igual');
    });

    testWidgets('apagado, los deslizadores no se pueden mover',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilaDeBandas(
            bandas: _bandas(5),
            nivelMinimo: -1500,
            nivelMaximo: 1500,
            habilitado: false,
            nivelDe: (_) => 0,
            onCambiar: (_, __) {},
          ),
        ),
      ));
      await tester.pump();

      for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
        expect(slider.onChanged, isNull);
      }
    });

    testWidgets('mover una banda avisa con su índice y su valor',
        (tester) async {
      int? indiceAvisado;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilaDeBandas(
            bandas: _bandas(3),
            nivelMinimo: -1500,
            nivelMaximo: 1500,
            habilitado: true,
            nivelDe: (_) => 0,
            onCambiar: (i, _) => indiceAvisado = i,
          ),
        ),
      ));
      await tester.pump();

      // Los deslizadores están girados 90°, así que se arrastra en
      // vertical para moverlos.
      await tester.drag(find.byType(Slider).at(1), const Offset(0, -40));
      await tester.pump();

      expect(indiceAvisado, 1);
    });

    testWidgets('un nivel fuera del rango no revienta', (tester) async {
      // El nivel guardado viene del disco y el rango lo informa el
      // celular: si cambiás de teléfono, uno puede no entrar en el otro.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilaDeBandas(
            bandas: _bandas(5),
            nivelMinimo: -1500,
            nivelMaximo: 1500,
            habilitado: true,
            nivelDe: (_) => 99999,
            onCambiar: (_, __) {},
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
