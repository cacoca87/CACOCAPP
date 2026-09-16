import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/plural.dart';

void main() {
  group('contarCanciones', () {
    test('una sola canción va en singular', () {
      // Este es el caso que estaba mal en cuatro lugares de la app:
      // decían "1 canciones".
      expect(contarCanciones(1), '1 canción');
    });

    test('cero y varias van en plural', () {
      expect(contarCanciones(0), '0 canciones');
      expect(contarCanciones(2), '2 canciones');
      expect(contarCanciones(338), '338 canciones');
    });
  });

  group('contar', () {
    test('sirve para cualquier par singular/plural', () {
      expect(contar(1, 'playlist', 'playlists'), '1 playlist');
      expect(contar(3, 'playlist', 'playlists'), '3 playlists');
    });
  });
}
