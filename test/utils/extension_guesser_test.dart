import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/extension_guesser.dart';

void main() {
  group('adivinarExtensionDeUrl', () {
    test('detecta la extensión de una URL normal con archivo', () {
      expect(adivinarExtensionDeUrl('https://ejemplo.com/audio/cancion.mp3'),
          'mp3');
    });

    test('detecta la extensión aunque la URL tenga query params', () {
      expect(
          adivinarExtensionDeUrl('https://ejemplo.com/cancion.m4a?token=abc'),
          'm4a');
    });

    test(
      'no agarra basura de un parámetro de query con punto (regresión del bug real)',
      () {
        // Esto es justo lo que rompía antes: partir la URL COMPLETA
        // por puntos (en vez de solo el último segmento de la ruta)
        // podía agarrar un "5" de "?rate=1.5" como si fuera la
        // extensión del archivo.
        expect(
            adivinarExtensionDeUrl('https://ejemplo.com/audio/stream?rate=1.5'),
            'mp3');
      },
    );

    test(
        'devuelve mp3 para una URL de streaming sin extensión real (ej. YouTube)',
        () {
      expect(
        adivinarExtensionDeUrl(
            'https://proxy.onrender.com/stream?id=dQw4w9WgXcQ'),
        'mp3',
      );
    });

    test('devuelve mp3 para una URL vacía o inválida', () {
      expect(adivinarExtensionDeUrl(''), 'mp3');
      expect(adivinarExtensionDeUrl('no es una url'), 'mp3');
    });

    test('ignora una "extensión" absurdamente larga (no es una extensión real)',
        () {
      expect(
        adivinarExtensionDeUrl(
            'https://ejemplo.com/archivo.estoNoEsUnaExtension'),
        'mp3',
      );
    });
  });
}
