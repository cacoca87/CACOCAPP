import 'dart:ui';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/geometria_del_video.dart';

/// Dónde se pone el video de YouTube en cada modo.
///
/// El overlay entero no se puede probar --lleva un WebView adentro, que
/// es una vista nativa de Android-- pero lo que de verdad puede salir
/// mal ahí son las cuentas, y esas son aritmética pura.
///
/// Y ya salieron mal: la barra chica del video se le montaba encima al
/// mini reproductor en los celulares con la letra agrandada.

GeometriaDelVideo _en(
  double ancho,
  double alto, {
  double miniPlayer = 67,
  EdgeInsets margenes = EdgeInsets.zero,
}) {
  return calcularGeometriaDelVideo(
    pantalla: Size(ancho, alto),
    margenesDelSistema: margenes,
    altoDelMiniReproductor: miniPlayer,
  );
}

/// Las pantallas que se prueban en todos lados: un celular chico, uno
/// normal, uno grande, el mismo en horizontal, y una ventana partida.
const _pantallas = [
  Size(320, 640), // celular angosto
  Size(360, 800), // el más común hoy
  Size(412, 915), // grande
  Size(800, 360), // horizontal
  Size(360, 300), // ventana partida a la mitad
];

void main() {
  group('la barra chica no se le monta al mini reproductor', () {
    // Es el fallo que ya pasó una vez. El alto del mini reproductor
    // crece con la letra del sistema, así que se prueba con la letra
    // normal (67) y con la del doble (106).
    for (final pantalla in _pantallas) {
      for (final miniPlayer in [0.0, 67.0, 106.0]) {
        test('${pantalla.width.toInt()}x${pantalla.height.toInt()}, '
            'mini reproductor de $miniPlayer', () {
          final g = _en(pantalla.width, pantalla.height,
              miniPlayer: miniPlayer,
              margenes: const EdgeInsets.only(top: 40, bottom: 24));

          final dondeEmpiezaElMiniReproductor =
              pantalla.height - 24 - miniPlayer;

          expect(g.barra.bottom, lessThanOrEqualTo(dondeEmpiezaElMiniReproductor),
              reason: 'la barra del video le pisa el mini reproductor');
        });
      }
    }
  });

  group('nada se sale de la pantalla ni mide en negativo', () {
    for (final pantalla in _pantallas) {
      test('${pantalla.width.toInt()}x${pantalla.height.toInt()}', () {
        final g = _en(pantalla.width, pantalla.height,
            margenes: const EdgeInsets.only(top: 40, bottom: 24));

        for (final entry in {
          'barra': g.barra,
          'video chico': g.videoChico,
          'video completo': g.videoCompleto,
          'zona de la letra': g.zonaDeLaLetra,
        }.entries) {
          final r = entry.value;
          expect(r.width, greaterThanOrEqualTo(0),
              reason: '${entry.key} mide un ancho negativo');
          expect(r.height, greaterThanOrEqualTo(0),
              reason: '${entry.key} mide un alto negativo');
          expect(r.left, greaterThanOrEqualTo(0),
              reason: '${entry.key} empieza fuera de la pantalla');
          expect(r.top, greaterThanOrEqualTo(0),
              reason: '${entry.key} empieza fuera de la pantalla');
        }
      });
    }
  });

  group('el video conserva la proporción 16:9', () {
    // Un video estirado se ve mal en cualquier teléfono, y es de esas
    // cosas que no dan error: simplemente quedan feas.
    for (final pantalla in _pantallas) {
      test('${pantalla.width.toInt()}x${pantalla.height.toInt()}', () {
        final g = _en(pantalla.width, pantalla.height);
        if (g.videoCompleto.height == 0) return; // no hay lugar: no aplica
        expect(g.videoCompleto.width / g.videoCompleto.height,
            closeTo(16 / 9, 0.01));
      });
    }
  });

  group('el video completo entra en la pantalla', () {
    for (final pantalla in _pantallas) {
      test('${pantalla.width.toInt()}x${pantalla.height.toInt()}', () {
        final g = _en(pantalla.width, pantalla.height,
            margenes: const EdgeInsets.only(top: 40));

        expect(g.videoCompleto.width, lessThanOrEqualTo(pantalla.width),
            reason: 'el video es más ancho que la pantalla');
        expect(g.videoCompleto.bottom, lessThanOrEqualTo(pantalla.height),
            reason: 'el video se sale por abajo');
      });
    }
  });

  group('el video chico entra en su barra', () {
    for (final pantalla in _pantallas) {
      test('${pantalla.width.toInt()}x${pantalla.height.toInt()}', () {
        final g = _en(pantalla.width, pantalla.height);

        expect(g.videoChico.top, greaterThanOrEqualTo(g.barra.top));
        expect(g.videoChico.bottom, lessThanOrEqualTo(g.barra.bottom));
        expect(g.videoChico.left, greaterThanOrEqualTo(g.barra.left));
        expect(g.videoChico.right, lessThanOrEqualTo(g.barra.right),
            reason: 'el video se sale de su barra a lo ancho');
      });
    }
  });

  group('queda lugar para los controles al lado del video chico', () {
    // Título y botones van AL LADO del video, nunca encima: es la única
    // forma comprobada de que los toques no se los quede el WebView.
    // Si no quedara ancho, no habría dónde ponerlos.
    for (final pantalla in _pantallas) {
      test('${pantalla.width.toInt()}x${pantalla.height.toInt()}', () {
        final g = _en(pantalla.width, pantalla.height);
        final anchoDeLosControles = g.barra.right - g.videoChico.right - 18;
        expect(anchoDeLosControles, greaterThan(60),
            reason: 'no queda lugar para el título ni los botones');
      });
    }
  });

  test('la zona de la letra empieza debajo del video, nunca encima', () {
    for (final pantalla in _pantallas) {
      final g = _en(pantalla.width, pantalla.height,
          margenes: const EdgeInsets.only(top: 40));
      expect(g.zonaDeLaLetra.top,
          greaterThanOrEqualTo(g.videoCompleto.bottom),
          reason: 'la letra se dibuja encima del video en '
              '${pantalla.width.toInt()}x${pantalla.height.toInt()}');
    }
  });

  group('casos extremos que no tienen que reventar', () {
    test('una ventana diminuta', () {
      // Android deja dejar la app en una ventana flotante muy chica.
      final g = _en(200, 120, margenes: const EdgeInsets.only(top: 40));
      expect(g.zonaDeLaLetra.height, greaterThanOrEqualTo(0));
      expect(g.videoCompleto.height, greaterThanOrEqualTo(0));
      expect(g.barra.top, greaterThanOrEqualTo(0));
    });

    test('una pantalla de alto cero no rompe las cuentas', () {
      final g = _en(360, 0);
      expect(g.barra.top, 0);
      expect(g.videoCompleto.height, 0);
      expect(g.zonaDeLaLetra.height, 0);
    });

    test('sin mini reproductor, la barra baja y usa ese lugar', () {
      final conMini = _en(360, 800, miniPlayer: 67);
      final sinMini = _en(360, 800, miniPlayer: 0);
      expect(sinMini.barra.top, greaterThan(conMini.barra.top),
          reason: 'sin mini reproductor la barra tiene que bajar');
      expect(sinMini.barra.top - conMini.barra.top, 67);
    });

    test('la barra de estado empuja el video hacia abajo', () {
      final sinBarra = _en(360, 800, margenes: EdgeInsets.zero);
      final conBarra = _en(360, 800, margenes: const EdgeInsets.only(top: 48));
      expect(conBarra.videoCompleto.top - sinBarra.videoCompleto.top, 48,
          reason: 'el video se metería debajo de la hora y la batería');
    });
  });
}
