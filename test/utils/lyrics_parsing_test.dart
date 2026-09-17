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

    test('saca las marcas de reedición, que llenan esta biblioteca', () {
      // Casos reales de los archivos del R2.
      expect(limpiarTituloParaBuscarLetra('Whole Lotta Love - Remaster'),
          'Whole Lotta Love');
      expect(limpiarTituloParaBuscarLetra('Kashmir (Remastered)'), 'Kashmir');
      expect(limpiarTituloParaBuscarLetra('Five Years - 2012 Remaster'),
          'Five Years');
      expect(limpiarTituloParaBuscarLetra('Ziggy Stardust - 2012 Remaster'),
          'Ziggy Stardust');
    });

    test('saca al artista invitado', () {
      expect(
        limpiarTituloParaBuscarLetra('Under Pressure (feat. David Bowie)'),
        'Under Pressure',
      );
      expect(limpiarTituloParaBuscarLetra('Algo [ft. Otro]'), 'Algo');
    });

    test('no se come el título de una canción que no es reedición', () {
      expect(limpiarTituloParaBuscarLetra('Paradise City'), 'Paradise City');
      expect(limpiarTituloParaBuscarLetra('Sweet Child O Mine'),
          'Sweet Child O Mine');
    });
  });

  group('parsearLrc', () {
    test('aguanta los tiempos escritos con un solo dígito', () {
      // Hay archivos LRC que escriben "[1:23]" en vez de "[01:23]". Con
      // el patrón estricto esa línea no coincidía con nada y se perdía.
      final lineas = parsearLrc('[1:5]Una línea\n[1:23.4]Otra');
      expect(lineas, hasLength(2));
      expect(lineas.first.tiempo, const Duration(minutes: 1, seconds: 5));
    });
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
