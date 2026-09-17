import 'package:flutter_test/flutter_test.dart';
import 'package:CACOCAPP/utils/eleccion_letra.dart';

Map<String, dynamic> _resultado({
  required String track,
  required String artista,
  num? duracion,
}) =>
    {
      'trackName': track,
      'artistName': artista,
      if (duracion != null) 'duration': duracion,
      'plainLyrics': 'letra de $track',
    };

void main() {
  group('elegirLetraDeLrclib', () {
    test('descarta la canción equivocada aunque venga primera', () {
      // El caso real: buscar "Amén" de "Amén" devuelve primero "Refuse
      // Amen" de la banda Amen, de 2:47, y la app mostraba esa letra en
      // inglés para una canción de 4:13.
      final resultados = [
        _resultado(track: 'Refuse Amen', artista: 'Amen', duracion: 167.4),
      ];
      expect(
        elegirLetraDeLrclib(resultados,
            duracion: const Duration(minutes: 4, seconds: 13)),
        isNull,
      );
    });

    test('elige la que dura lo mismo, no la primera', () {
      final resultados = [
        _resultado(track: 'Otra cosa', artista: 'Otra banda', duracion: 167),
        _resultado(track: 'Amén', artista: 'Amén', duracion: 253),
      ];
      final elegida = elegirLetraDeLrclib(resultados,
          duracion: const Duration(minutes: 4, seconds: 13));
      expect(elegida!['trackName'], 'Amén');
    });

    test('tolera unos segundos de diferencia', () {
      // Un remaster o un archivo con silencio al final se corre poco.
      final resultados = [
        _resultado(track: 'Flor Pálida', artista: 'Marc Anthony', duracion: 280)
      ];
      expect(
        elegirLetraDeLrclib(resultados,
            duracion: const Duration(minutes: 4, seconds: 44))!['trackName'],
        'Flor Pálida',
      );
    });

    test('entre dos que duran igual, gana la del artista buscado', () {
      final resultados = [
        _resultado(track: 'Roxanne', artista: 'Un cover', duracion: 200),
        _resultado(track: 'Roxanne', artista: 'The Police', duracion: 200),
      ];
      final elegida = elegirLetraDeLrclib(
        resultados,
        duracion: const Duration(seconds: 200),
        artistaBuscado: 'The Police',
      );
      expect(elegida!['artistName'], 'The Police');
    });

    test('sin saber cuánto dura la canción, se queda con la primera', () {
      // No se puede descartar nada: es exactamente lo que hacía antes.
      final resultados = [
        _resultado(track: 'Primera', artista: 'A', duracion: 100),
        _resultado(track: 'Segunda', artista: 'B', duracion: 200),
      ];
      expect(elegirLetraDeLrclib(resultados)!['trackName'], 'Primera');
      expect(
        elegirLetraDeLrclib(resultados, duracion: Duration.zero)!['trackName'],
        'Primera',
      );
    });

    test('si ningún resultado dice cuánto dura, se queda con la primera', () {
      final resultados = [
        _resultado(track: 'Sin dato', artista: 'A'),
        _resultado(track: 'Tampoco', artista: 'B'),
      ];
      expect(
        elegirLetraDeLrclib(resultados,
            duracion: const Duration(seconds: 200))!['trackName'],
        'Sin dato',
      );
    });

    test('una lista vacía no elige nada', () {
      expect(elegirLetraDeLrclib([]), isNull);
      expect(
        elegirLetraDeLrclib([], duracion: const Duration(seconds: 200)),
        isNull,
      );
    });

    test('una duración de cero o negativa en el resultado se ignora', () {
      final resultados = [
        _resultado(track: 'Rota', artista: 'A', duracion: 0),
        _resultado(track: 'Buena', artista: 'A', duracion: 200),
      ];
      expect(
        elegirLetraDeLrclib(resultados,
            duracion: const Duration(seconds: 200))!['trackName'],
        'Buena',
      );
    });

    test('el caso real de "Amén": mismo largo, artista distinto, se descarta',
        () {
      // Lo que pasó de verdad y llegó a verse en pantalla: "Amén" de
      // Amén dura 188 s, y en la base hay un "AmEN!" de Bring Me the
      // Horizon de 189,5 s. Segundo y medio de diferencia. Pasó el
      // filtro de duración y la app mostró una letra en inglés llena de
      // insultos para una canción de pop-rock peruano.
      final resultados = [
        _resultado(
            track: 'AmEN!', artista: 'Bring Me the Horizon', duracion: 189.55),
      ];
      expect(
        elegirLetraDeLrclib(
          resultados,
          duracion: const Duration(seconds: 188),
          artistaBuscado: 'Amén',
          exigirArtista: true,
        ),
        isNull,
      );
    });

    test('exigiendo artista, el correcto igual se encuentra', () {
      final resultados = [
        _resultado(
            track: 'AmEN!', artista: 'Bring Me the Horizon', duracion: 189.55),
        _resultado(track: 'Amén', artista: 'Amén', duracion: 188),
      ];
      final elegida = elegirLetraDeLrclib(
        resultados,
        duracion: const Duration(seconds: 188),
        artistaBuscado: 'Amén',
        exigirArtista: true,
      );
      expect(elegida!['artistName'], 'Amén');
    });

    test('sin exigir artista, se comporta como antes', () {
      final resultados = [
        _resultado(track: 'Otra', artista: 'Otro', duracion: 188),
      ];
      expect(
        elegirLetraDeLrclib(resultados,
            duracion: const Duration(seconds: 188))!['trackName'],
        'Otra',
      );
    });

    test('la tilde del artista no lo convierte en otro artista', () {
      // La base de letras casi nunca escribe las tildes. Comparando
      // letra por letra, "Amén" y "Amen" son dos artistas distintos, y
      // entonces la regla del artista --la que existe para que no se
      // cuele una letra ajena-- rechazaba la letra CORRECTA.
      final resultados = [
        _resultado(track: 'Te Quiero', artista: 'Amen', duracion: 188),
      ];
      final elegida = elegirLetraDeLrclib(
        resultados,
        duracion: const Duration(seconds: 188),
        artistaBuscado: 'Amén',
        exigirArtista: true,
      );
      expect(elegida, isNotNull);
      expect(elegida!['trackName'], 'Te Quiero');
    });

    group('cuando todavía no se sabe cuánto dura la canción', () {
      // Pasa de verdad: se abre la letra apenas arranca el tema, antes
      // de que el reproductor sepa la duración. Ahí la duración no
      // puede descartar nada, pero el artista sí.
      test('gana el del artista que coincide, no el primero de la lista',
          () {
        final resultados = [
          _resultado(track: 'AmEN!', artista: 'Bring Me the Horizon'),
          _resultado(track: 'Amén', artista: 'Amén'),
        ];
        final elegida = elegirLetraDeLrclib(
          resultados,
          duracion: null,
          artistaBuscado: 'Amén',
        );
        expect(elegida!['artistName'], 'Amén');
      });

      test('exigiendo artista, uno ajeno se sigue descartando', () {
        final resultados = [
          _resultado(track: 'AmEN!', artista: 'Bring Me the Horizon'),
        ];
        expect(
          elegirLetraDeLrclib(
            resultados,
            duracion: null,
            artistaBuscado: 'Amén',
            exigirArtista: true,
          ),
          isNull,
        );
      });

      test('sin artista conocido, sigue devolviendo el primero', () {
        final resultados = [
          _resultado(track: 'Una', artista: 'Alguien'),
          _resultado(track: 'Otra', artista: 'Otro'),
        ];
        expect(
          elegirLetraDeLrclib(resultados, duracion: null)!['trackName'],
          'Una',
        );
      });
    });
  });
}
