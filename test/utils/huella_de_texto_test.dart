import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/huella_de_texto.dart';

void main() {
  group('huellaCorta', () {
    test('el mismo texto da siempre la misma huella', () {
      // Es LO que tiene que cumplir: la huella forma parte del nombre
      // de un archivo guardado en el celular, y mañana hay que poder
      // volver a encontrarlo. Por eso no se usa `hashCode`, que no
      // garantiza dar lo mismo entre una ejecución y la siguiente.
      const ruta = 'file:///storage/emulated/0/Music/Rock/01 - Intro.mp3';
      expect(huellaCorta(ruta), huellaCorta(ruta));
    });

    test(
        'EL CASO REAL: dos archivos con el mismo nombre en carpetas '
        'distintas no se pisan', () {
      // Tener "/Music/Rock/01 - Intro.mp3" y "/Music/Jazz/01 - Intro.mp3"
      // es de lo más común en un celular. Sin esto, las dos caían en el
      // mismo lugar de la caché y la segunda mostraba la carátula, el
      // álbum y el artista de la primera.
      expect(
        huellaCorta('file:///Music/Rock/01 - Intro.mp3'),
        isNot(huellaCorta('file:///Music/Jazz/01 - Intro.mp3')),
      );
    });

    test('siempre mide lo mismo y sirve como nombre de archivo', () {
      for (final texto in ['', 'a', 'Amén - Te Quiero.mp3', 'x' * 500]) {
        final huella = huellaCorta(texto);
        expect(huella.length, 8);
        expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(huella), isTrue,
            reason: '"$huella" tiene que poder ser parte de un nombre');
      }
    });

    test('un cambio mínimo cambia la huella', () {
      expect(huellaCorta('cancion.mp3'), isNot(huellaCorta('cancion2.mp3')));
      expect(huellaCorta('/a/x.mp3'), isNot(huellaCorta('/b/x.mp3')));
    });
  });
}
