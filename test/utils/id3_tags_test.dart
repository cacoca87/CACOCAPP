import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/id3_tags.dart';

void main() {
  group('leerTagDeTexto', () {
    test('lee un tag que viene como texto', () {
      expect(leerTagDeTexto({'Album': 'Appetite for Destruction'}, 'Album'),
          'Appetite for Destruction');
    });

    test('lee un tag que viene como mapa con clave "text"', () {
      // El paquete `id3` devuelve algunos tags así.
      expect(
        leerTagDeTexto({
          'Artist': {'text': 'Tom Petty'}
        }, 'Artist'),
        'Tom Petty',
      );
    });

    test('convierte a texto cualquier otra forma en vez de reventar', () {
      // Un MP3 con el tag guardado de forma rara no puede tirar abajo la
      // lista de canciones.
      expect(leerTagDeTexto({'Album': 1994}, 'Album'), '1994');
    });

    test('devuelve null si el tag no está', () {
      expect(leerTagDeTexto({'Album': 'X'}, 'Artist'), isNull);
    });

    test('devuelve null si no hay tags', () {
      expect(leerTagDeTexto(null, 'Album'), isNull);
    });

    test('un tag vacío o con solo espacios cuenta como ausente', () {
      // Pasa seguido: MP3 con el campo creado pero sin completar. Si se
      // devolviera cadena vacía, se mostraría un artista en blanco en
      // vez de caer al respaldo del nombre del archivo.
      expect(leerTagDeTexto({'Album': ''}, 'Album'), isNull);
      expect(leerTagDeTexto({'Album': '   '}, 'Album'), isNull);
      expect(
        leerTagDeTexto({
          'Artist': {'text': '  '}
        }, 'Artist'),
        isNull,
      );
    });

    test('recorta los espacios de los costados', () {
      expect(leerTagDeTexto({'Artist': '  Queen  '}, 'Artist'), 'Queen');
    });

    test('un mapa sin la clave "text" no rompe', () {
      final r = leerTagDeTexto({
        'Album': {'otra': 'cosa'}
      }, 'Album');
      expect(r, isNotNull);
    });
  });
}
