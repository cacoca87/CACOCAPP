import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/lyrics_parsing.dart';

void main() {
  group('limpiarTituloParaBuscarLetra', () {
    test('saca "(Official Video)" del título', () {
      expect(
        limpiarTituloParaBuscarLetra('Roxanne (Official Video)'),
        'Roxanne',
      );
    });

    test('saca "[Official Video]", "(Lyrics)" y "HD" combinados', () {
      expect(
        limpiarTituloParaBuscarLetra('Azuquita [Official Video] (Lyrics) HD'),
        'Azuquita',
      );
    });

    test('no toca un título que ya está limpio', () {
      expect(
        limpiarTituloParaBuscarLetra('Knockin On Heavens Door'),
        'Knockin On Heavens Door',
      );
    });

    test('colapsa espacios extra que quedan después de sacar el ruido', () {
      expect(
        limpiarTituloParaBuscarLetra('Sin Documentos   (Video Oficial)'),
        'Sin Documentos',
      );
    });

    test('es insensible a mayúsculas/minúsculas', () {
      expect(
        limpiarTituloParaBuscarLetra(
            'Runnin Down A Dream (OFFICIAL MUSIC VIDEO)'),
        'Runnin Down A Dream',
      );
    });
  });

  group('parsearLrc', () {
    test('parsea una línea LRC simple (mm:ss.cc)', () {
      final lineas = parsearLrc('[00:12.50]Primera línea');
      expect(lineas, hasLength(1));
      expect(
          lineas.first.tiempo, const Duration(seconds: 12, milliseconds: 500));
      expect(lineas.first.texto, 'Primera línea');
    });

    test('parsea varias líneas y las devuelve ordenadas por tiempo', () {
      final lineas = parsearLrc(
        '[00:20.00]Segunda\n[00:05.00]Primera\n[00:40.00]Tercera',
      );
      expect(lineas.map((l) => l.texto), ['Primera', 'Segunda', 'Tercera']);
    });

    test('ignora líneas sin marca de tiempo', () {
      final lineas =
          parsearLrc('[ar:Artista]\n[00:01.00]Única línea real\nsin marca');
      expect(lineas, hasLength(1));
      expect(lineas.first.texto, 'Única línea real');
    });

    test('ignora líneas con marca de tiempo pero sin texto', () {
      final lineas = parsearLrc('[00:01.00]\n[00:02.00]Con texto');
      expect(lineas, hasLength(1));
      expect(lineas.first.texto, 'Con texto');
    });

    test('devuelve lista vacía para contenido vacío o sin formato LRC', () {
      expect(parsearLrc(''), isEmpty);
      expect(parsearLrc('esto no tiene marcas de tiempo'), isEmpty);
    });

    test('soporta minutos de dos dígitos', () {
      final lineas = parsearLrc('[03:45.00]Línea tardía');
      expect(lineas.first.tiempo, const Duration(minutes: 3, seconds: 45));
    });
  });
}
